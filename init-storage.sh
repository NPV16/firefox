#!/bin/bash
set -e

# ============================================================================
# Storage Initialization Script
# ============================================================================

echo "🔧 Initializing storage system..."

# 加载环境变量
DATA_DIR=${DATA_DIR:-/data}
ENABLE_PERSISTENCE=${ENABLE_PERSISTENCE:-true}
FIREFOX_PROFILE_DIR=${FIREFOX_PROFILE_DIR:-/data/config/firefox}
FIREFOX_PROFILE_NAME=${FIREFOX_PROFILE_NAME:-default}

# 检查是否启用持久化
if [ "${ENABLE_PERSISTENCE}" != "true" ]; then
    echo "⚠️  Data persistence is disabled - using temporary storage"
    exit 0
fi

echo "✅ Data persistence enabled"

# 创建基础目录结构
echo "📁 Creating directory structure..."
mkdir -p "${DATA_DIR}"
mkdir -p "${DATA_DIR}/downloads"
mkdir -p "${DATA_DIR}/bookmarks"
mkdir -p "${DATA_DIR}/cache"
mkdir -p "${DATA_DIR}/config"
mkdir -p "${DATA_DIR}/tmp"
mkdir -p "${DATA_DIR}/backups"

# 设置目录权限
chmod -R 777 "${DATA_DIR}" 2>/dev/null || true

# Firefox Profile 初始化
echo "🦊 Initializing Firefox profile..."

if [ ! -d "${FIREFOX_PROFILE_DIR}" ]; then
    echo "📝 Creating new Firefox profile..."
    mkdir -p "${FIREFOX_PROFILE_DIR}"
    
    # 复制模板配置文件
    if [ -d "/etc/firefox/template" ]; then
        echo "📋 Copying template configuration..."
        cp -r /etc/firefox/template/* "${FIREFOX_PROFILE_DIR}/" 2>/dev/null || true
    fi
    
    # 创建必要的子目录
    mkdir -p "${FIREFOX_PROFILE_DIR}/storage"
    mkdir -p "${FIREFOX_PROFILE_DIR}/storage/default"
    mkdir -p "${FIREFOX_PROFILE_DIR}/storage/permanent"
    mkdir -p "${FIREFOX_PROFILE_DIR}/storage/temporary"
    mkdir -p "${FIREFOX_PROFILE_DIR}/indexedDB"
    mkdir -p "${FIREFOX_PROFILE_DIR}/cache2"
    mkdir -p "${FIREFOX_PROFILE_DIR}/bookmarkbackups"
    mkdir -p "${FIREFOX_PROFILE_DIR}/datareporting"
    mkdir -p "${FIREFOX_PROFILE_DIR}/sessionstore-backups"
    mkdir -p "${FIREFOX_PROFILE_DIR}/saved-telemetry-pings"
    mkdir -p "${FIREFOX_PROFILE_DIR}/storage/default/http+++localhost+${NOVNC_PORT:-5800}"
    
    # 创建空的 Local Storage 文件
    echo '{}' > "${FIREFOX_PROFILE_DIR}/storage/default/http+++localhost+${NOVNC_PORT:-5800}/ls.json"
    
    # 创建 profiles.ini
    cat > "${FIREFOX_PROFILE_DIR}/../profiles.ini" << EOF
[General]
StartWithLastProfile=1

[Profile0]
Name=${FIREFOX_PROFILE_NAME}
IsRelative=0
Path=${FIREFOX_PROFILE_DIR}
Default=1
EOF
    
    echo "✅ New Firefox profile created at: ${FIREFOX_PROFILE_DIR}"
else
    echo "📂 Using existing Firefox profile: ${FIREFOX_PROFILE_DIR}"
    
    # 确保必要的子目录存在
    mkdir -p "${FIREFOX_PROFILE_DIR}/storage/default"
    mkdir -p "${FIREFOX_PROFILE_DIR}/storage/permanent"
    mkdir -p "${FIREFOX_PROFILE_DIR}/storage/temporary"
    mkdir -p "${FIREFOX_PROFILE_DIR}/indexedDB"
    mkdir -p "${FIREFOX_PROFILE_DIR}/cache2"
    mkdir -p "${FIREFOX_PROFILE_DIR}/bookmarkbackups"
fi

# 修复文件权限
echo "🔐 Setting file permissions..."
find "${FIREFOX_PROFILE_DIR}" -type d -exec chmod 777 {} \; 2>/dev/null || true
find "${FIREFOX_PROFILE_DIR}" -type f -exec chmod 666 {} \; 2>/dev/null || true

# 创建 Firefox 配置目录的符号链接
echo "🔗 Setting up Firefox configuration..."
rm -rf /root/.mozilla 2>/dev/null || true
mkdir -p /root/.mozilla
ln -sf "${FIREFOX_PROFILE_DIR}" /root/.mozilla/firefox/${FIREFOX_PROFILE_NAME}
cp "${FIREFOX_PROFILE_DIR}/../profiles.ini" /root/.mozilla/firefox/ 2>/dev/null || true

# 检查挂载点
if mountpoint -q "${DATA_DIR}"; then
    MOUNT_INFO=$(df -h "${DATA_DIR}" | tail -1)
    echo "📌 Data directory is mounted: ${MOUNT_INFO}"
else
    echo "⚠️  Data directory is not mounted externally - data may not persist"
fi

# 显示存储信息
echo ""
echo "📊 Storage Summary:"
echo "================================================================================"
echo "📁 Data Directory: ${DATA_DIR}"
echo "├── 📂 downloads/          - Download files"
echo "├── 📂 bookmarks/          - Bookmarks (HTML & JSON backups)"
echo "├── 📂 cache/              - Firefox disk cache"
echo "├── 📂 config/             - Configuration files"
echo "│   └── 📂 firefox/        - Firefox profile"
echo "│       ├── 📂 storage/    - Local Storage data"
echo "│       ├── 📂 indexedDB/  - IndexedDB databases"
echo "│       ├── 📂 cache2/     - Internal cache"
echo "│       └── 📜 prefs.js    - User preferences"
echo "├── 📂 tmp/                - Temporary files"
echo "└── 📂 backups/            - Automatic backups"
echo ""
echo "💾 Profile Location: ${FIREFOX_PROFILE_DIR}"
echo "🔗 Linked to: /root/.mozilla/firefox/${FIREFOX_PROFILE_NAME}"
echo ""
echo "📈 Storage Usage:"
du -sh "${DATA_DIR}"/* 2>/dev/null | while read line; do echo "   $line"; done
echo "================================================================================"

echo "✅ Storage initialization completed successfully!"