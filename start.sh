#!/bin/bash

# 设置环境变量
export DISPLAY=${DISPLAY:-:99}
export DISPLAY_WIDTH=${DISPLAY_WIDTH:-1280}
export DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-720}
export VNC_PASSWORD=${VNC_PASSWORD:-admin}
export VNC_PORT=${VNC_PORT:-5900}
export NOVNC_PORT=${NOVNC_PORT:-7860}
export DATA_DIR=${DATA_DIR:-/data}
export LANG=${LANG:-C.UTF-8}
export LC_ALL=${LC_ALL:-C.UTF-8}

# 确保目录存在
mkdir -p /root/.vnc
mkdir -p /var/log/supervisor

# 创建VNC密码文件（如果不存在）
if [ ! -f /root/.vnc/passwd ]; then
    x11vnc -storepasswd "$VNC_PASSWORD" /root/.vnc/passwd > /dev/null 2>&1
    echo "VNC password set to: $VNC_PASSWORD"
fi

# 设置 Firefox 配置和本地存储目录
FIREFOX_DATA_DIR="${DATA_DIR}/firefox"

# 如果/data/firefox目录不存在或为空，使用默认配置
if [ ! -d "${FIREFOX_DATA_DIR}" ] || [ -z "$(ls -A ${FIREFOX_DATA_DIR} 2>/dev/null)" ]; then
    echo "Using default Firefox profile..."
    # 确保目标目录存在
    mkdir -p "${FIREFOX_DATA_DIR}"
    # 复制默认配置到/data/firefox
    cp -r /default-firefox-profile/* "${FIREFOX_DATA_DIR}/" 2>/dev/null || true
fi

# 清理旧的.mozilla目录并创建软链接
rm -rf /root/.mozilla 2>/dev/null || true
ln -sf "${FIREFOX_DATA_DIR}" /root/.mozilla

# 创建其他必要的子目录
mkdir -p "${DATA_DIR}/downloads"
mkdir -p "${DATA_DIR}/logs"

# 设置supervisor配置中的环境变量
cat > /etc/supervisor/conf.d/environment.conf << EOF
[program:environment]
command=/bin/true
environment=DISPLAY="$DISPLAY",DISPLAY_WIDTH="$DISPLAY_WIDTH",DISPLAY_HEIGHT="$DISPLAY_HEIGHT",VNC_PORT="$VNC_PORT",NOVNC_PORT="$NOVNC_PORT"
autostart=false
autorestart=false
stdout_logfile=/dev/null
stderr_logfile=/dev/null
EOF

# 启动Supervisor来管理所有进程
echo "======================================="
echo "Starting container with configuration:"
echo "======================================="
echo "Display: $DISPLAY"
echo "Display resolution: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
echo "VNC port: $VNC_PORT"
echo "noVNC port: $NOVNC_PORT"
echo "VNC password: $VNC_PASSWORD"
echo "Firefox data directory: ${FIREFOX_DATA_DIR}"
echo "Downloads directory: ${DATA_DIR}/downloads"
echo "======================================="
echo "Access noVNC at: http://localhost:${NOVNC_PORT}"
echo "======================================="

# 启动supervisord（前台运行）
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n
