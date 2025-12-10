#!/bin/bash
set -e

# ============================================================================
# 启动脚本 - 使用KasmVNC
# ============================================================================

# 设置环境变量
export DISPLAY=${DISPLAY:-:99}
export DISPLAY_WIDTH=${DISPLAY_WIDTH:-1280}
export DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-720}
export VNC_PASSWORD=${VNC_PASSWORD:-admin}
export VNC_PORT=${VNC_PORT:-5901}
export WEB_PORT=${WEB_PORT:-7860}
export DATA_DIR=${DATA_DIR:-/data}
export ENABLE_PERSISTENCE=${ENABLE_PERSISTENCE:-true}
export FIREFOX_PROFILE_DIR=${FIREFOX_PROFILE_DIR:-/data/config/firefox}
export LANG=${LANG:-en_US.UTF-8}
export LANGUAGE=${LANG:-en_US:en}
export LC_ALL=${LC_ALL:-en_US.UTF-8}

# 启动信息
echo "================================================================================"
echo "🚀 Starting Firefox with KasmVNC"
echo "================================================================================"
echo "Display: ${DISPLAY} (${DISPLAY_WIDTH}x${DISPLAY_HEIGHT})"
echo "VNC Port: ${VNC_PORT}, Web Port: ${WEB_PORT}"
echo "Data Directory: ${DATA_DIR}"
echo "================================================================================"

# 初始化存储
if [ -f /usr/local/bin/init-storage.sh ]; then
    /usr/local/bin/init-storage.sh
fi

# 设置字体缓存
if [ ! -f /root/.fonts.cache ]; then
    fc-cache -f > /dev/null 2>&1
    touch /root/.fonts.cache
fi

# 清理旧的X锁文件
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

# 启动Xvfb
echo "Starting Xvfb..."
Xvfb ${DISPLAY} -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24 -ac +extension GLX +render -noreset -nolisten tcp &
XVFB_PID=$!
sleep 2

if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo "Failed to start Xvfb"
    exit 1
fi

# 设置Xauthority
export XAUTHORITY=/tmp/.Xauthority
touch ${XAUTHORITY}
xauth generate ${DISPLAY} . trusted 2>/dev/null || true

# 启动Fluxbox
echo "Starting Fluxbox..."
fluxbox &
sleep 1

# KasmVNC密码设置
KASM_PASSWD_FILE="/root/.vnc/passwd.kasm"
if [ ! -f "${KASM_PASSWD_FILE}" ] || [ ! -s "${KASM_PASSWD_FILE}" ]; then
    echo "Setting KasmVNC password..."
    mkdir -p /root/.vnc
    echo "${VNC_PASSWORD}" | kasmvncpasswd -f "${KASM_PASSWD_FILE}" - 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to set password with kasmvncpasswd, using fallback"
        echo -e "${VNC_PASSWORD}\n${VNC_PASSWORD}\n" | vncpasswd "${KASM_PASSWD_FILE}" 2>/dev/null
    fi
fi

# 启动KasmVNC服务器
echo "Starting KasmVNC server..."
kasmvncserver ${DISPLAY} \
    -depth 24 \
    -geometry ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} \
    -rfbauth "${KASM_PASSWD_FILE}" \
    -rfbport ${VNC_PORT} \
    -websocketPort ${WEB_PORT} \
    -frameRate 24 \
    -interface 0.0.0.0 \
    -log *:stdout:100 \
    -fg &
KASM_PID=$!
sleep 3

# 启动Firefox
echo "Starting Firefox..."
firefox --display=${DISPLAY} --profile ${FIREFOX_PROFILE_DIR} --new-instance &
sleep 3

# 启动Supervisor
echo "Starting Supervisor..."
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf &

# 显示访问信息
echo ""
echo "================================================================================"
echo "✅ System is ready!"
echo "================================================================================"
echo ""
echo "🌐 WEB ACCESS (推荐):"
echo "   URL: http://YOUR_SERVER_IP:${WEB_PORT}/vnc.html"
echo ""
echo "🔌 VNC CLIENT ACCESS:"
echo "   Host: YOUR_SERVER_IP"
echo "   Port: ${VNC_PORT}"
echo ""
echo "🔐 Password: ${VNC_PASSWORD}"
echo ""
echo "💡 Tips:"
echo "   • Web界面支持自适应画质、快捷键和文件传输"
echo "   • 连接后可以点击工具栏设置画质以节省带宽"
echo "   • 默认帧率限制为24fps，可在启动参数中调整"
echo "================================================================================"

# 保持容器运行
wait $KASM_PID
