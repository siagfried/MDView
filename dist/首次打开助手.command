#!/bin/bash
# MDView 首次打开助手：解除 Gatekeeper 隔离 + 设为 .md 默认程序
APP=""
for p in "/Applications/MDView.app" "$HOME/Applications/MDView.app"; do
  [ -d "$p" ] && APP="$p" && break
done
if [ -z "$APP" ]; then
  echo "⚠️  没找到 MDView.app。请先把它拖进「应用程序」文件夹，再运行本脚本。"
  read -n 1 -s -r -p "按任意键退出…"; exit 1
fi
echo "① 解除隔离属性（解决「无法验证开发者」）…"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null
echo "② 注册并设为 .md 文件的默认打开程序…"
defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add \
  '{"LSHandlerContentType"="net.daringfireball.markdown";"LSHandlerRoleAll"="com.davidwong.mdview";}'
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
killall Finder 2>/dev/null
echo "③ 启动 MDView…"
open "$APP"
echo "✅ 完成。之后双击任意 .md 即可用 MDView 阅读。"
read -n 1 -s -r -p "按任意键关闭本窗口…"
