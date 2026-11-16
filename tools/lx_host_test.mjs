// Node 版 LX 自定义源宿主原型：用于在写 Flutter 之前验证
// 1) 酷狗搜索接口是否可用  2) 真实音源脚本能否解析出播放地址
//
// 用法: node tools/lx_host_test.mjs [音源js地址] [搜索关键词]

const SOURCE_URL =
  process.argv[2] ??
  'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/helloworld/latest.js';
const KEYWORD = process.argv[3] ?? '晴天 周杰伦';
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

import http from 'node:http';
import https from 'node:https';

function httpRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    let hops = 0;
    const go = (target, method, body) => {
      const lib = target.startsWith('https:') ? https : http;
      const req = lib.request(
        target,
        {
          method,
          headers: {
            'User-Agent': UA,
            'Accept-Encoding': 'identity',
            ...(options.headers || {}),
          },
          timeout: options.timeout || 15000,
        },
        (res) => {
          const chunks = [];
          res.on('data', (c) => chunks.push(c));
          res.on('end', () => {
            const status = res.statusCode || 0;
            if ([301, 302, 303, 307, 308].includes(status) && res.headers.location && hops < 5) {
              hops += 1;
              const next = new URL(res.headers.location, target).href;
              go(next, status === 303 ? 'GET' : method, status === 303 ? undefined : body);
              return;
            }
            resolve({
              body: Buffer.concat(chunks).toString('utf8'),
              statusCode: status,
              url: target,
              headers: res.headers,
            });
          });
        },
      );
      req.on('timeout', () => req.destroy(new Error('请求超时')));
      req.on('error', reject);
      if (body) req.write(body);
      req.end();
    };
    go(url, options.method || 'GET', options.body);
  });
}

function stripTags(s) {
  return String(s ?? '')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .trim();
}

async function searchKugou(keyword) {
  const url =
    'https://songsearch.kugou.com/song_search_v2?keyword=' +
    encodeURIComponent(keyword) +
    '&page=1&pagesize=3&platform=WebFilter&tag=em&filter=2&iscorrection=1&privilege_filter=0';
  const r = await httpRequest(url, { headers: { Referer: 'https://www.kugou.com/' } });
  const json = JSON.parse(r.body);
  return (json?.data?.lists ?? []).map((it) => ({
    source: 'kg',
    hash: it.FileHash,
    name: stripTags(it.SongName),
    singer: stripTags(it.SingerName),
    albumName: stripTags(it.AlbumName),
    albumId: it.AlbumID,
    interval: formatInterval(it.Duration),
  }));
}

function formatInterval(sec) {
  const s = Number(sec) || 0;
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
}

// ---------- LX 宿主 shim ----------
const handlers = {};
let initedResolve;
const initedPromise = new Promise((res) => (initedResolve = res));

const lx = {
  version: 2,
  env: 'node',
  currentScriptInfo: {},
  EVENT_NAMES: { inited: 'inited', request: 'request', updateAlert: 'updateAlert' },
  on(event, handler) {
    handlers[event] = handler;
  },
  send(event, data) {
    if (event === 'inited') {
      console.log('[inited] sources =', Object.keys(data?.sources ?? {}).join(', '));
      initedResolve(data);
    } else if (event === 'updateAlert') {
      console.log('[updateAlert]', data?.log);
    }
  },
  request(url, options = {}, cb) {
    httpRequest(url, options).then(
      (r) => cb(null, r),
      (e) => cb(e),
    );
    return () => {};
  },
  utils: {
    buffer: {
      from: (v, enc) => Buffer.from(v, enc === 'utf-8' ? 'utf8' : enc),
      bufToString: (buf, enc) => Buffer.from(buf).toString(enc === 'utf-8' ? 'utf8' : enc),
    },
    crypto: {},
  },
};

globalThis.lx = lx;

function loadSource(code) {
  // 与移动端一致：初始化完成前抛错即视为失败
  const fn = new Function(code);
  fn();
}

const main = async () => {
  console.log('== 1. 酷狗搜索 ==');
  const songs = await searchKugou(KEYWORD);
  songs.forEach((s) => console.log(`  ${s.name} - ${s.singer} | hash=${s.hash}`));
  if (!songs.length) throw new Error('搜索无结果');
  const song = songs[0];

  console.log('\n== 2. 下载音源脚本 ==');
  const src = await httpRequest(SOURCE_URL);
  console.log(`  status=${src.statusCode} bytes=${src.body.length}`);

  console.log('\n== 3. 执行音源脚本 ==');
  loadSource(src.body);
  const initData = await Promise.race([
    initedPromise,
    new Promise((_, rej) => setTimeout(() => rej(new Error('inited 超时')), 10000)),
  ]);
  console.log('  sources:', JSON.stringify(initData.sources.kg));

  console.log('\n== 4. 请求播放地址 ==');
  const musicInfo = song;
  for (const type of ['320k', '128k']) {
    const t0 = Date.now();
    try {
      const url = await handlers.request({
        source: 'kg',
        action: 'musicUrl',
        info: { type, musicInfo },
      });
      console.log(`  [${type}] ${Date.now() - t0}ms -> ${String(url).slice(0, 160)}`);
      const head = await httpRequest(url, { method: 'HEAD' });
      console.log(`     HEAD status=${head.statusCode} type=${head.headers['content-type'] ?? '?'} len=${head.headers['content-length'] ?? '?'}`);
      break;
    } catch (e) {
      console.log(`  [${type}] 失败: ${e?.message ?? e}`);
    }
  }
  console.log('\n完成');
};

main().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});
