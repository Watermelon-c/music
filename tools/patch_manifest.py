#!/usr/bin/env python3
"""给 flutter create 生成的 AndroidManifest.xml 打补丁：

1. 加上 INTERNET 权限（Flutter 模板只在 debug/profile 里给，release 包必须自己加）
2. application 上允许明文 HTTP —— 音源返回的直链很多是 http://
3. 改应用名

脚本是幂等的，可以重复执行。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

APP_LABEL = "椰子音乐"


def patch(manifest: Path) -> None:
    text = manifest.read_text(encoding="utf-8")
    before = text

    # 1. INTERNET 权限
    if "android.permission.INTERNET" not in text:
        m = re.search(r"<manifest[^>]*>", text)
        if not m:
            raise SystemExit("找不到 <manifest> 标签")
        text = (
            text[: m.end()]
            + '\n    <uses-permission android:name="android.permission.INTERNET"/>'
            + text[m.end() :]
        )

    # 2. 允许明文 HTTP
    if "android:usesCleartextTraffic" not in text:
        m = re.search(r"<application\b[^>]*>", text)
        if not m:
            raise SystemExit("找不到 <application> 标签")
        tag = m.group(0)
        new_tag = tag[:-1] + '\n        android:usesCleartextTraffic="true">'
        text = text[: m.start()] + new_tag + text[m.end() :]

    # 3. 应用名
    text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_LABEL}"', text, count=1)

    manifest.write_text(text, encoding="utf-8")

    print(f"patched: {manifest}")
    print(f"  changed: {text != before}")
    for key in ("android.permission.INTERNET", "android:usesCleartextTraffic", APP_LABEL):
        print(f"  has {key}: {key in text}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("用法: python3 tools/patch_manifest.py <AndroidManifest.xml>")
    patch(Path(sys.argv[1]))
