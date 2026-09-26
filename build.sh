#!/bin/bash
# 一键构建 MDView.app（macOS 13+ / arm64）
# 用法：./build.sh            在当前目录生成 MDView.app
#       ./build.sh --sign "证书名"   用指定证书签名（默认 ad-hoc）
set -euo pipefail
cd "$(dirname "$0")"

SIGN_ID="-"
if [ "${1:-}" = "--sign" ] && [ -n "${2:-}" ]; then SIGN_ID="$2"; fi

RES="build-resources"
mkdir -p "$RES"

# 1) 第三方前端库（构建时从 CDN 取，许可证详见 THIRD-PARTY.md）
fetch() { [ -f "$RES/$2" ] || curl -fsSL -o "$RES/$2" "$1"; }
fetch "https://cdn.jsdelivr.net/npm/markdown-it@14/dist/markdown-it.min.js"                        markdown-it.min.js
fetch "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/highlight.min.js"                   highlight.min.js
fetch "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/styles/github.min.css"              hljs-github.min.css
fetch "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/styles/github-dark.min.css"         hljs-github-dark.min.css
fetch "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js"                                      mathjax-tex-svg.js
fetch "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"                                mermaid.min.js

# 2) 编译（arm64；要通用二进制可另编 x86_64 后 lipo 合并）
echo "==> 编译 main.swift"
swiftc -O -target arm64-apple-macos13.0 -o "$RES/MDView" main.swift -framework Cocoa -framework WebKit

# 3) 组装 App
APP="MDView.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$RES/MDView" "$APP/Contents/MacOS/MDView"
cp Resources/MDView.icns Resources/default.css "$APP/Contents/Resources/"
cp "$RES"/*.js "$RES"/*.css "$APP/Contents/Resources/" 2>/dev/null || true
cp Info.plist "$APP/Contents/Info.plist"

# 4) 签名（未做 Apple 公证，首次打开需右键 → 打开）
echo "==> 签名（$SIGN_ID）"
codesign --force --deep --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict "$APP" && echo "✅ 完成：$PWD/$APP"
