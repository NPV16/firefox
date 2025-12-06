#!/bin/bash
echo "Firefox 正在启动，插件已预装..."
exec firefox-esr --display=:99 --kiosk "https://idx.google.com"
