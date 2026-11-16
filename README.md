# LX 播放器（个人自用）

一个 Flutter 写的安卓音乐播放器：**酷狗搜索** + **LX 自定义音源解析播放地址** + 在线播放 / 收藏。
没有服务器，没有账号，所有东西都在手机上跑。

> ⚠️ 仅限个人自用，请勿公开分发或商用。音源脚本来自第三方作者，版权与可用性由上游决定。

## 它是怎么工作的

```
搜索：App → 酷狗 song_search_v2 接口 → 歌名/歌手/FileHash
播放：App → 隐藏 WebView 里跑 LX 音源脚本 → 脚本请求第三方解析接口 → 返回 mp3 直链
     → just_audio 播放（带 UA/Referer）
```

- `assets/lx/host.html` 是 LX 自定义源的宿主：给脚本注入 `globalThis.lx`
  （`on/send/request/EVENT_NAMES/utils.buffer/utils.crypto.md5`），
  网络请求回抛给 Dart 代发，所以不受 CORS 限制。
- 每个音源脚本跑在独立的“假 globalThis”里，互相隔离，可以同时导入多个、失败了自动换源。
- 已实现：`buffer.from/bufToString`、`crypto.md5`、`crypto.randomBytes`、`setTimeout`。
- 未实现：`crypto.aesEncrypt`、`crypto.rsaEncrypt`、`zlib.inflate/deflate`。
  依赖这些的音源（部分 QQ/网易源）会报错，换 `helloworld`、`changqing` 这类源就好。

## 用 GitHub 打包 APK（不需要本地装 Flutter）

1. 注册 / 登录 GitHub，点右上角 **+ → New repository**，名字随便（例如 `lx-player`），
   选 **Private**（私人仓库），**不要**勾选 README/gitignore，创建。
2. 在电脑上进入本目录，把代码推上去（把地址换成你自己的）：

   ```bash
   git init
   git add .
   git commit -m "feat: 初始化 LX 播放器"
   git branch -M main
   git remote add origin https://github.com/<你的用户名>/lx-player.git
   git push -u origin main
   ```

   > 也可以用 GitHub 网页版 “uploading an existing file” 把整个文件夹拖上去，
   > 但要保证 `.github/workflows/build-apk.yml` 也在里面。

3. 打开仓库页面的 **Actions** 标签，会看到 `build-apk` 正在跑（第一次约 5–10 分钟）。
4. 跑完后点进这次运行，页面底部 **Artifacts** 里下载 `lx-music-apk`（是个 zip）。
5. 解压得到 `app-release.apk`，传到手机上安装（需要允许“安装未知来源应用”）。
   这个包用 debug 证书签名，能直接装，但**不能上架应用商店**。

## 第一次打开怎么用

1. 进 **音源** 页 → 点一个「推荐音源」（推荐 `HelloWorld 聚合`，今天验证可用），
   等提示“导入成功”。导入失败就换一个。
2. 回 **搜索** 页，输入歌名 / 歌手，例如 `晴天 周杰伦`。
3. 点歌曲就开始播放；点底部迷你条可以进播放页，点 ❤️ 收藏。

音质在 **音源 → 播放音质** 里选，解析失败会自动降到 128k 再试一次。

## 常见问题

| 现象 | 原因 / 处理 |
| --- | --- |
| 搜索没有结果 | 酷狗接口偶尔抽风，换个关键词或稍后重试 |
| 提示“所有音源都没解析出地址” | 音源失效了，去音源页换一个（这是常态） |
| 提示缺少 `aesEncrypt` | 该音源用到了未实现的能力，换源 |
| 播放没声音但进度在走 | 直链是 http 的，检查是否被系统拦截；本项目已开 cleartext |
| APK 装不上 | 手机开了“未知来源”限制；或 Android 版本低于 5.0 |

## 目录结构

```
lib/
  main.dart              入口、底部导航、隐藏 WebView 挂载
  app_state.dart         全局状态：搜索 / 播放 / 收藏 / 音源管理
  models/models.dart     Song、SourceEntry
  services/
    kugou_api.dart       酷狗搜索
    lx_host.dart         WebView 宿主，Dart <-> JS 桥
    player_service.dart  just_audio 封装
  ui/                    搜索页、收藏页、音源页、播放页
assets/lx/
  host.html              LX 自定义源宿主（核心）
  md5.js                 md5 实现，给脚本的 crypto.md5 用
tools/
  lx_host_test.mjs       Node 版宿主原型（验证解析链路用）
  host_test.mjs          直接跑 host.html + 真实音源的集成测试
  patch_manifest.py      CI 里给 AndroidManifest 打补丁
```

## 本地开发（可选）

装了 Flutter 之后：

```bash
flutter create --platforms=android --org com.lxmusic --project-name lxmusic_app .
python3 tools/patch_manifest.py android/app/src/main/AndroidManifest.xml
flutter pub get
flutter run          # 连手机
flutter build apk    # 出包
```

## 已验证的链路（2026-11-16 实测）

- 酷狗搜索：`song_search_v2` 可用，返回 `FileHash`（直接喂给音源当歌曲 id）
- 宿主：`tools/host_test.mjs` 在 Node 里直接加载 `assets/lx/host.html` + 真实音源脚本，
  跑通 `inited` → `musicUrl` → 真实直链

| 音源 | 实测结果 |
| --- | --- |
| `helloworld` | ✅ 酷狗 320k / 128k 都解析出真实直链，`HEAD` 返回 `200 audio/mpeg` |
| `changqing` | ⚠️ 能解析出地址，但直链所在 CDN 返回 522，可能时好时坏 |
| `lx` | ❌ 当前报 `unknow error` |
| `fish` / `xinghai` / `sixyin` | 未测完（脚本在网络不好时会卡住，App 里有 20s 超时兜底） |

> 音源失效是这个生态的常态，失效就换一个。演示时优先用 `HelloWorld 聚合`。

## 如果 Actions 构建失败

1. 打开失败的 run，展开 **构建 release APK** 那一步的日志，把红色报错整段复制给我。
2. 同时看看 **静态检查（不阻断构建）** 的日志——`flutter analyze` 会指出 Dart 编译错误的具体行号。
3. 常见原因：某个依赖版本和 Flutter 3.24.5 不兼容（改 `pubspec.yaml` 的版本号即可）。
