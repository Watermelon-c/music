// 在 Node 里跑 assets/lx/host.html + 真实音源脚本，
// 验证真正要装进 App 的那份宿主代码（假 globalThis、Buffer、请求桥接）能跑通。
//
// 用法: node tools/host_test.mjs [音源js地址] [关键词]
import fs from 'node:fs';
import vm from 'node:vm';
import http from 'node:http';
import https from 'node:https';

const SOURCE_URL =
  process.argv[2] ??
  'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/helloworld/latest.js';
const KEYWORD = process.argv[3] ?? '晴天 周杰伦';
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

function httpRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    let hops = 0;
    const go = (target, method, body) => {
      const lib = target.startsWith('https:') ? https : http;
      const req = lib.request(
        target,
        {
          method,
          headers: { 'User-Agent': UA, 'Accept-Encoding': 'identity', ...(options.headers || {}) },
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

const stripTags = (s) =>
  String(s ?? '')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .trim();

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
    interval: '00:00',
  }));
}

// ---------------- 在 vm 里装载 host.html ----------------
const messages = [];
const waiters = [];

function dispatch(msg) {
  messages.push(msg);
  for (let i = 0; i < waiters.length; i++) {
    if (waiters[i].type === msg.type) {
      const w = waiters.splice(i, 1)[0];
      w.resolve(msg);
      return;
    }
  }
}

function pull(type, timeoutMs = 20000) {
  const idx = messages.findIndex((m) => m.type === type);
  if (idx >= 0) return Promise.resolve(messages.splice(idx, 1)[0]);
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`等待 ${type} 超时，已收到: ${JSON.stringify(messages)}`)), timeoutMs);
    waiters.push({
      type,
      resolve: (m) => {
        clearTimeout(timer);
        messages.splice(messages.indexOf(m), 1);
        resolve(m);
      },
    });
  });
}

const sandbox = {
  console,
  setTimeout,
  clearTimeout,
  setInterval,
  clearInterval,
  URL,
  TextEncoder,
  TextDecoder,
  btoa: (s) => Buffer.from(String(s), 'binary').toString('base64'),
  atob: (s) => Buffer.from(String(s), 'base64').toString('binary'),
  window: {
    LxBridge: {
      postMessage: (raw) => {
        let msg;
        try {
          msg = JSON.parse(raw);
        } catch (e) {
          console.log('[bridge] 非法消息', raw);
          return;
        }
        if (msg.type === 'http') {
          handleHttp(msg);
        } else {
          dispatch(msg);
        }
      },
    },
  },
};
vm.createContext(sandbox);

async function handleHttp(msg) {
  let payload;
  try {
    const r = await httpRequest(msg.url, msg.options);
    payload = { statusCode: r.statusCode, body: r.body, url: r.url, headers: r.headers };
  } catch (e) {
    payload = { __error: String(e?.message ?? e) };
  }
  sandbox.window.__lxHttpDone(msg.rid, JSON.stringify(payload));
}

const hostHtml = fs.readFileSync(new URL('../assets/lx/host.html', import.meta.url), 'utf8');
const md5Js = fs.readFileSync(new URL('../assets/lx/md5.js', import.meta.url), 'utf8');
const hostJs = hostHtml.match(/<script>([\s\S]*?)<\/script>/)[1];

vm.runInContext(md5Js, sandbox, { filename: 'md5.js' });
vm.runInContext(hostJs, sandbox, { filename: 'host.html' });

// md5 自检
vm.runInContext("__check = (typeof __md5 === 'function' && __md5('abc') === '900150983cd24fb0d6963f7d28e17f72')", sandbox);

const main = async () => {
  await pull('ready');
  console.log('== host.html 已就绪 ==');
  console.log('  md5 自检:', sandbox.__check ? 'PASS' : 'FAIL');

  const songs = await searchKugou(KEYWORD);
  console.log('== 搜索 ==');
  songs.forEach((s) => console.log(`  ${s.name} - ${s.singer} hash=${s.hash}`));

  const src = await httpRequest(SOURCE_URL);
  console.log(`== 音源脚本 ${src.body.length} 字节，开始加载 ==`);
  sandbox.window.__lxAddSource(src.body, 'test', JSON.stringify({ name: 'test' }));

  const inited = await pull('inited');
  console.log('  inited:', Object.keys(inited.sources).join(','));

  const song = songs[0];
  console.log(`== 解析播放地址: ${song.name} ==`);
  sandbox.window.__lxRequest('r1', 'test', 'kg', '320k', JSON.stringify(song));
  const result = await Promise.race([pull('result'), pull('fail')]);
  if (result.type === 'result') {
    console.log('  OK:', String(result.url).slice(0, 150));
    const head = await httpRequest(result.url, { method: 'HEAD' });
    console.log(`  HEAD ${head.statusCode} ${head.headers['content-type']} ${head.headers['content-length']}`);
  } else {
    console.log('  FAIL:', result.message);
  }

  // 再验证一次 128k 兜底
  sandbox.window.__lxRequest('r2', 'test', 'kg', '128k', JSON.stringify(song));
  const r2 = await Promise.race([pull('result'), pull('fail')]);
  console.log('  128k:', r2.type === 'result' ? 'OK ' + String(r2.url).slice(0, 100) : 'FAIL ' + r2.message);
};

main().catch((e) => {
  console.error('FATAL', e?.stack || e);
  process.exit(1);
});
