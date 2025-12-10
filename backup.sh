#!/bin/bash
set -e

# ============================================================================
# Backup Script
# ============================================================================

# 配置文件
BACKUP_DIR="${1:-/data/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="firefox_backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
COMPRESSED_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# 环境变量
DATA_DIR=${DATA_DIR:-/data}
FIREFOX_PROFILE_DIR=${FIREFOX_PROFILE_DIR:-/data/config/firefox}

echo "💾 Starting backup process..."
echo "📁 Backup directory: ${BACKUP_DIR}"
echo "⏰ Timestamp: ${TIMESTAMP}"

# 验证备份目录
if [ ! -d "${BACKUP_DIR}" ]; then
    echo "📂 Creating backup directory..."
    mkdir -p "${BACKUP_DIR}"
fi

# 创建临时备份目录
echo "📦 Creating temporary backup structure..."
mkdir -p "${BACKUP_PATH}"

# 备份数据
echo "📤 Backing up data..."

# 1. Firefox 配置文件
if [ -d "${FIREFOX_PROFILE_DIR}" ]; then
    echo "   📝 Backing up Firefox profile..."
    mkdir -p "${BACKUP_PATH}/firefox_profile"
    
    # 备份重要文件，排除缓存
    rsync -a --exclude='cache2' --exclude='startupCache' \
        "${FIREFOX_PROFILE_DIR}/" "${BACKUP_PATH}/firefox_profile/" 2>/dev/null || true
else
    echo "   ⚠️  Firefox profile not found: ${FIREFOX_PROFILE_DIR}"
fi

# 2. 下载文件
if [ -d "${DATA_DIR}/downloads" ]; then
    echo "   📥 Backing up downloads..."
    mkdir -p "${BACKUP_PATH}/downloads"
    cp -r "${DATA_DIR}/downloads"/* "${BACKUP_PATH}/downloads/" 2>/dev/null || true
fi

# 3. 书签
if [ -d "${DATA_DIR}/bookmarks" ]; then
    echo "   📑 Backing up bookmarks..."
    mkdir -p "${BACKUP_PATH}/bookmarks"
    cp -r "${DATA_DIR}/bookmarks"/* "${BACKUP_PATH}/bookmarks/" 2>/dev/null || true
fi

# 4. 配置文件
if [ -d "${DATA_DIR}/config" ]; then
    echo "   ⚙️  Backing up config..."
    mkdir -p "${BACKUP_PATH}/config"
    find "${DATA_DIR}/config" -maxdepth 1 -type f -name "*.ini" -exec cp {} "${BACKUP_PATH}/config/" \; 2>/dev/null || true
fi

# 创建备份元数据
echo "📋 Creating backup metadata..."
cat > "${BACKUP_PATH}/BACKUP_INFO.md" << EOF
# Firefox noVNC Backup
## Backup Information

- **Date:** $(date)
- **Backup ID:** ${TIMESTAMP}
- **Container:** $(hostname)
- **Data Directory:** ${DATA_DIR}
- **Firefox Profile:** ${FIREFOX_PROFILE_DIR}

## Contents

1. Firefox Profile
   - Location: firefox_profile/
   - Includes: preferences, extensions, Local Storage, IndexedDB
   - Excludes: cache files

2. Downloads
   - Location: downloads/
   - All downloaded files

3. Bookmarks
   - Location: bookmarks/
   - HTML and JSON bookmark files

4. Configuration
   - Location: config/
   - Container configuration files

## Restoration

To restore this backup:

\`\`\`bash
# Extract the backup
tar -xzf ${BACKUP_NAME}.tar.gz -C /restore/

# Restore Firefox profile
cp -r /restore/${BACKUP_NAME}/firefox_profile/* ${FIREFOX_PROFILE_DIR}/

# Restore downloads
cp -r /restore/${BACKUP_NAME}/downloads/* ${DATA_DIR}/downloads/

# Restore bookmarks
cp -r /restore/${BACKUP_NAME}/bookmarks/* ${DATA_DIR}/bookmarks/

# Restore config
cp -r /restore/${BACKUP_NAME}/config/* ${DATA_DIR}/config/
\`\`\`

## Notes

- Restore process may require Firefox restart
- Some in-use files may not be backed up
- Cache files are excluded for efficiency
EOF

# 创建简化的恢复脚本
cat > "${BACKUP_PATH}/restore.sh" << 'EOF'
#!/bin/bash
set -e

echo "🔄 Starting restore process..."

# 检查参数
if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_directory>"
    echo "Example: $0 /restore/firefox_backup_20231201_120000"
    exit 1
fi

BACKUP_SRC="$1"
DATA_DIR="${DATA_DIR:-/data}"
FIREFOX_PROFILE_DIR="${FIREFOX_PROFILE_DIR:-/data/config/firefox}"

# 验证备份源
if [ ! -d "${BACKUP_SRC}" ]; then
    echo "❌ Backup directory not found: ${BACKUP_SRC}"
    exit 1
fi

echo "📂 Backup source: ${BACKUP_SRC}"
echo "📁 Target data directory: ${DATA_DIR}"

# 停止 Firefox 进程
echo "⏸️  Stopping Firefox..."
pkill -f firefox 2>/dev/null || true
sleep 2

# 恢复数据
echo "📤 Restoring data..."

# 恢复 Firefox 配置文件
if [ -d "${BACKUP_SRC}/firefox_profile" ]; then
    echo "   📝 Restoring Firefox profile..."
    mkdir -p "${FIREFOX_PROFILE_DIR}"
    rsync -a "${BACKUP_SRC}/firefox_profile/" "${FIREFOX_PROFILE_DIR}/"
fi

# 恢复下载文件
if [ -d "${BACKUP_SRC}/downloads" ]; then
    echo "   📥 Restoring downloads..."
    mkdir -p "${DATA_DIR}/downloads"
    cp -r "${BACKUP_SRC}/downloads"/* "${DATA_DIR}/downloads/" 2>/dev/null || true
fi

# 恢复书签
if [ -d "${BACKUP_SRC}/bookmarks" ]; then
    echo "   📑 Restoring bookmarks..."
    mkdir -p "${DATA_DIR}/bookmarks"
    cp -r "${BACKUP_SRC}/bookmarks"/* "${DATA_DIR}/bookmarks/" 2>/dev/null || true
fi

echo "✅ Restore completed!"
echo "🚀 Please restart the container to apply changes"
EOF

chmod +x "${BACKUP_PATH}/restore.sh"

# 压缩备份
echo "🗜️  Compressing backup..."
cd "${BACKUP_DIR}"
tar -czf "${COMPRESSED_FILE}" "${BACKUP_NAME}" 2>/dev/null

# 计算备份大小
BACKUP_SIZE=$(du -h "${COMPRESSED_FILE}" | cut -f1)

# 清理临时文件
echo "🧹 Cleaning up..."
rm -rf "${BACKUP_PATH}"

# 清理旧备份（保留最近10个）
echo "📦 Managing old backups..."
cd "${BACKUP_DIR}"
ls -t firefox_backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

# 显示结果
echo ""
echo "================================================================================"
echo "✅ Backup completed successfully!"
echo "================================================================================"
echo ""
echo "📊 Backup Details:"
echo "   📁 File: ${COMPRESSED_FILE}"
echo "   📦 Size: ${BACKUP_SIZE}"
echo "   ⏰ Created: $(date)"
echo ""
echo "📈 Available backups:"
ls -lh firefox_backup_*.tar.gz 2>/dev/null | while read line; do echo "   $line"; done || echo "   No previous backups found"
echo ""
echo "💡 Restoration:"
echo "   1. Copy backup to container: docker cp backup.tar.gz container:/restore/"
echo "   2. Extract: tar -xzf backup.tar.gz -C /restore/"
echo "   3. Run restore: /restore/firefox_backup_*/restore.sh /restore/firefox_backup_*/"
echo "================================================================================"