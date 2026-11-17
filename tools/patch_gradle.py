#!/usr/bin/env python3
"""给 flutter create 生成的 android/app/build.gradle 打补丁：
把 release 的签名从 debug 换成 key.properties 里指定的密钥（没有该文件则仍用 debug）。

兼容 Groovy 的两种写法：`signingConfig signingConfigs.debug` 和 `signingConfig = signingConfigs.debug`。
脚本幂等（用注释标记判断是否已打过）；任何一步没匹配上只打印警告，不会让构建失败。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

MARK_KEYS = "// >>> yezi keystore"
MARK_SIGN = "// >>> yezi signing"

KEYS_BLOCK = """// >>> yezi keystore
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
// <<< yezi keystore

"""


def patch(gradle: Path) -> None:
    text = gradle.read_text(encoding="utf-8")
    before = text

    # 1) 在 android { 之前读取 key.properties
    if MARK_KEYS not in text:
        m = re.search(r"^android[ \t]*\{", text, re.M)
        if m:
            text = text[: m.start()] + KEYS_BLOCK + text[m.start() :]
            print("  + keystoreProperties 已注入")
        else:
            print("  ! 没找到 'android {'，跳过")

    # 2) 注入 signingConfigs（缩进跟随 buildTypes）
    if MARK_SIGN not in text:
        m = re.search(r"^([ \t]*)buildTypes\s*\{", text, re.M)
        if m:
            indent = m.group(1)
            i1 = indent + "    "
            i2 = indent + "        "
            i3 = indent + "            "
            block = (
                indent + MARK_SIGN + "\n"
                + indent + "signingConfigs {\n"
                + i1 + "release {\n"
                + i2 + "if (keystorePropertiesFile.exists()) {\n"
                + i3 + "keyAlias keystoreProperties['keyAlias']\n"
                + i3 + "keyPassword keystoreProperties['keyPassword']\n"
                + i3 + "storeFile file(keystoreProperties['storeFile'])\n"
                + i3 + "storePassword keystoreProperties['storePassword']\n"
                + i2 + "}\n"
                + i1 + "}\n"
                + indent + "}\n"
                + indent + "// <<< yezi signing\n\n"
                + indent + "buildTypes {"
            )
            text = text[: m.start()] + block + text[m.end() :]
            print("  + signingConfigs 已注入")
        else:
            print("  ! 没找到 'buildTypes {'，跳过")

    # 3) release 改用我们的签名
    pattern = re.compile(r"signingConfig\s*=?\s*signingConfigs\.debug")
    if pattern.search(text):
        text = pattern.sub(
            "signingConfig keystorePropertiesFile.exists() "
            "? signingConfigs.release : signingConfigs.debug",
            text,
        )
        print("  + release 改用 key.properties 签名")
    else:
        print("  ! 没找到 'signingConfig signingConfigs.debug'，跳过")

    gradle.write_text(text, encoding="utf-8")
    print(f"patched: {gradle} (changed={text != before})")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("用法: python3 tools/patch_gradle.py <android/app/build.gradle>")
    patch(Path(sys.argv[1]))
