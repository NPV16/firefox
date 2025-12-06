#!/bin/bash
echo "Firefox 正在启动 (使用默认首页)..."
echo "请通过Web界面访问，并手动安装 'Auto Refresh Page' 插件。"
# 关键修改：移除 --kiosk 和 URL 参数，让Firefox自然启动
exec firefox-esr --display=:99
