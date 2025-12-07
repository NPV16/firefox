#!/bin/bash
set -e

echo "===== Firefox + noVNC 容器启动 ====="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 设置默认环境变量
: ${VNC_PASSWORD:=alpine}
: ${NOVNC_PORT:=7860}
: ${VNC_PORT:=5901}
: ${DISPLAY_WIDTH:=1280}
: ${DISPLAY_HEIGHT:=720}
: ${DISPLAY_DEPTH:=24}

echo "=== 配置信息 ==="
echo "• noVNC端口: ${NOVNC_PORT}"
echo "• VNC端口: ${VNC_PORT}"
echo "• 分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}"

# 创建必要的目录
mkdir -p ~/.fluxbox /var/log

# 检查Firefox
if ! command -v firefox > /dev/null 2>&1; then
    echo "• 安装Firefox..."
    apk add --no-cache firefox 2>/dev/null || true
fi

# VNC密码处理（直接使用 -passwd 参数）
if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "none" ] && [ "$VNC_PASSWORD" != "off" ]; then
    echo "• 设置VNC密码..."
    
    # x11vnc的-passwd参数只支持最多8位密码
    PASSWORD_TO_USE="$VNC_PASSWORD"
    if [ ${#VNC_PASSWORD} -gt 8 ]; then
        echo "• 注意：VNC密码超过8位，将使用前8位字符"
        PASSWORD_TO_USE=$(echo "$VNC_PASSWORD" | cut -c1-8)
    fi
    
    VNC_AUTH_OPT="-passwd $PASSWORD_TO_USE"
    echo "• VNC密码: 已启用 (使用: ${PASSWORD_TO_USE})"
else
    echo "• VNC密码: 未设置 (无密码连接)"
    VNC_AUTH_OPT="-nopw"
fi

# 生成Supervisor配置文件
cat > /etc/supervisord.conf << EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
logfile_maxbytes=1MB
logfile_backups=1
loglevel=info

[program:xvfb]
command=Xvfb :0 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH} -ac +extension GLX +render -noreset
autorestart=true
startretries=5
stdout_logfile=/var/log/xvfb.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/xvfb.err.log
stderr_logfile_maxbytes=1MB

[program:fluxbox]
command=fluxbox
autorestart=true
environment=DISPLAY=:0
startretries=5
stdout_logfile=/var/log/fluxbox.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/fluxbox.err.log
stderr_logfile_maxbytes=1MB

[program:x11vnc]
command=x11vnc -display :0 -forever -shared -rfbport ${VNC_PORT} ${VNC_AUTH_OPT} -noxdamage
autorestart=true
startretries=5
stdout_logfile=/var/log/x11vnc.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/x11vnc.err.log
stderr_logfile_maxbytes=1MB

[program:novnc]
command=websockify --web /usr/share/novnc ${NOVNC_PORT} localhost:${VNC_PORT}
autorestart=true
startretries=5
stdout_logfile=/var/log/novnc.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/novnc.err.log
stderr_logfile_maxbytes=1MB
EOF

# 创建Fluxbox配置
cat > ~/.fluxbox/init << 'EOF'
session.screen0.toolbar.visible: false
session.screen0.fullMaximization: false
background: none
[begin] (fluxbox)
[exec] (Firefox) {firefox --display=:0 --no-remote --new-instance}
[end]
EOF

# 设置noVNC首页
if [ -f /usr/share/novnc/vnc.html ]; then
    cp /usr/share/novnc/vnc.html /usr/share/novnc/index.html
elif [ -f /usr/share/webapps/novnc/vnc.html ]; then
    cp /usr/share/webapps/novnc/vnc.html /usr/share/novnc/index.html
fi

echo "=== 启动完成 ==="
echo "• 访问地址: http://<主机IP>:${NOVNC_PORT}"
echo "• VNC服务器端口: ${VNC_PORT}"
echo "• 显示分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
echo "================================"

# 启动所有服务
exec /usr/bin/supervisord -c /etc/supervisord.conf
