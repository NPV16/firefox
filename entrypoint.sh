#!/bin/bash
set -e

# 创建VNC密码文件（非交互方式）
if [ -n "$VNC_PASSWORD" ]; then
    echo "设置VNC密码..."
    mkdir -p ~/.vnc
    
    # 使用非交互方式创建密码文件
    # 方法1: 使用expect模拟交互（如果安装了expect）
    # 方法2: 使用openssl生成兼容格式的密码文件
    
    # 使用openssl生成VNC密码文件（兼容x11vnc格式）
    # VNC密码是8位，如果超过8位会被截断
    PASS_LENGTH=${#VNC_PASSWORD}
    if [ $PASS_LENGTH -gt 8 ]; then
        echo "注意：VNC密码超过8位，将被截断为前8位字符"
        TRUNCATED_PASSWORD=$(echo "$VNC_PASSWORD" | cut -c1-8)
        echo "$TRUNCATED_PASSWORD" | x11vnc -storepasswd - ~/.vnc/passwd -f
    else
        echo "$VNC_PASSWORD" | x11vnc -storepasswd - ~/.vnc/passwd -f
    fi
    
    # 如果上面的方法失败，使用备用方法
    if [ ! -f ~/.vnc/passwd ] || [ ! -s ~/.vnc/passwd ]; then
        echo "使用备用方法生成密码文件..."
        # 创建一个临时的expect脚本
        cat > /tmp/setup_vnc_password.exp << 'EOF'
#!/usr/bin/expect -f
set password [lindex $argv 0]
set password_file [lindex $argv 1]
spawn x11vnc -storepasswd $password $password_file
expect "Enter VNC password:"
send "$password\r"
expect "Verify password:"
send "$password\r"
expect eof
EOF
        chmod +x /tmp/setup_vnc_password.exp
        
        # 使用expect脚本
        if command -v expect > /dev/null 2>&1; then
            /tmp/setup_vnc_password.exp "$VNC_PASSWORD" ~/.vnc/passwd
        else
            echo "警告：无法生成VNC密码文件，VNC连接将不需要密码"
            rm -f ~/.vnc/passwd
        fi
        rm -f /tmp/setup_vnc_password.exp
    fi
    
    if [ -f ~/.vnc/passwd ] && [ -s ~/.vnc/passwd ]; then
        VNC_PASSWD_OPT="-passwdfile ~/.vnc/passwd"
        echo "VNC密码已成功设置"
    else
        echo "警告：VNC密码文件生成失败，VNC连接将不需要密码"
        VNC_PASSWD_OPT=""
    fi
else
    echo "警告：未设置VNC_PASSWORD环境变量，VNC连接将不需要密码"
    VNC_PASSWD_OPT=""
fi

# 更新Supervisor配置中的端口
echo "配置noVNC端口：${NOVNC_PORT}"
echo "配置VNC端口：${VNC_PORT}"

# 生成动态的Supervisor配置文件
cat > /etc/supervisord.conf << EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
logfile_maxbytes=50MB
logfile_backups=10
loglevel=info
pidfile=/var/run/supervisord.pid

[program:xvfb]
command=Xvfb :0 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH} -ac +extension GLX +render -noreset
autorestart=true
startretries=10
stdout_logfile=/var/log/xvfb.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/xvfb.error.log
stderr_logfile_maxbytes=1MB

[program:fluxbox]
command=fluxbox
autorestart=true
environment=DISPLAY=:0
startretries=10
stdout_logfile=/var/log/fluxbox.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/fluxbox.error.log
stderr_logfile_maxbytes=1MB

[program:x11vnc]
command=x11vnc -display :0 -forever -shared -rfbport ${VNC_PORT} ${VNC_PASSWD_OPT} -noxdamage -bg -o /var/log/x11vnc.log
autorestart=true
startretries=10
stdout_logfile=/var/log/x11vnc.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/x11vnc.error.log
stderr_logfile_maxbytes=1MB

[program:novnc]
command=websockify --web /usr/share/novnc ${NOVNC_PORT} localhost:${VNC_PORT}
autorestart=true
startretries=10
stdout_logfile=/var/log/novnc.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/novnc.error.log
stderr_logfile_maxbytes=1MB
EOF

# 设置Fluxbox配置
mkdir -p ~/.fluxbox
cat > ~/.fluxbox/init << EOF
session.screen0.toolbar.visible: false
session.screen0.fullMaximization: false
background: none
[begin] (fluxbox)
[exec] (Firefox) {firefox --display=:0 --no-remote --new-instance}
[end]
EOF

# 创建日志目录
mkdir -p /var/log

echo "================================"
echo "Firefox + noVNC 容器已启动"
echo "noVNC Web访问: http://<host>:${NOVNC_PORT}"
echo "VNC服务器端口: ${VNC_PORT}"
if [ -n "$VNC_PASSWORD" ] && [ -f ~/.vnc/passwd ]; then
    echo "VNC密码已设置"
else
    echo "警告：VNC连接未设置密码"
fi
echo "显示分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
echo "================================"

# 启动Supervisor
exec /usr/bin/supervisord -c /etc/supervisord.conf
