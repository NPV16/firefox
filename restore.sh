#!/bin/bash
set -e

# ============================================================================
# Restore Script
# ============================================================================

echo "🔄 Starting restore process..."

# 检查参数
if [ $# -eq 0 ]; then
    echo "❌ Usage: $0 <backup_file.tar.gz>"
    echo "   Example: $0 /data/backups/firefox_backup_20231201_120000.tar.gz"
    echo "   Example: $0 /backup/firefox_backup_20231201_120000.tar.gz"
    exit 1
fi

BACKUP_FILE="$1"
RESTORE_DIR="/tmp/restore_$(date +%s)"

# 环境变量
DATA_DIR=${DATA_DIR:-/data}
FIREFOX_PROFILE_DIR=${FIREFOX_PROFILE_DIR:-/data/config/firefox}

echo "📂 Backup file: ${BACKUP_FILE}"
echo "📁 Restore directory: ${RESTORE_DIR}"
echo "🎯 Target data directory: ${DATA_DIR}"

# 验证备份文件
if [ ! -f "${BACKUP_FILE}" ]; then
    echo "❌ Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

# 检查文件类型
if file "${BACKUP_FILE}" | grep -q "gzip compressed data"; then
    echo "✅ Valid gzip compressed backup file"
else
    echo "❌ Invalid backup file format"
    exit 1
fi

# 创建临时解压目录
echo "📦 Creating temporary directory..."
mkdir -p "${RESTORE_DIR}"

# 解压备份文件
echo "🗜️  Extracting backup..."
if ! tar -xzf "${BACKUP_FILE}" -C "${RESTORE_DIR}"; then
    echo "❌ Failed to extract backup file"
    rm -rf "${RESTORE_DIR}"
    exit 1
fi

# 查找备份数据
BACKUP_DATA=$(find "${RESTORE_DIR}" -name "BACKUP_INFO.md" -exec dirname {} \; | head -1)

if [ -z "${BACKUP_DATA}" ]; then
    echo "❌ Could not find backup data in extracted files"
    echo "📂 Extracted content:"
    ls -la "${RESTORE_DIR}"
    rm -rf "${RESTORE_DIR}"
    exit 1
fi

echo "✅ Found backup data at: ${BACKUP_DATA}"

# 显示备份信息
if [ -f "${BACKUP_DATA}/BACKUP_INFO.md" ]; then
    echo ""
    echo "📋 Backup Information:"
    echo "================================================================================"
    head -20 "${BACKUP_DATA}/BACKUP_INFO.md" | grep -v "^#"
    echo "================================================================================"
fi

# 停止 Firefox 进程
echo "⏸️  Stopping Firefox processes..."
pkill -f firefox 2>/dev/null || true
sleep 3

# 确认 Firefox 已停止
if pgrep -f firefox > /dev/null 2>&1; then
    echo "⚠️  Firefox still running, forcing termination..."
    pkill -9 -f firefox 2>/dev/null || true
    sleep 2
fi

# 备份当前数据（可选）
echo "💾 Creating backup of current data..."
CURRENT_BACKUP="/tmp/pre_restore_backup_$(date +%s)"
mkdir -p "${CURRENT_BACKUP}"
cp -r "${DATA_DIR}/config" "${CURRENT_BACKUP}/" 2>/dev/null || true
echo "   Current data backed up to: ${CURRENT_BACKUP}"

# 开始恢复
echo ""
echo "📤 Restoring data..."
echo "================================================================================"

# 恢复 Firefox 配置文件
if [ -d "${BACKUP_DATA}/firefox_profile" ]; then
    echo "1️⃣  Restoring Firefox profile..."
    
    # 创建目标目录
    mkdir -p "${FIREFOX_PROFILE_DIR}"
    
    # 清理现有配置（保留缓存）
    echo "   🧹 Cleaning existing profile (preserving cache)..."
    find "${FIREFOX_PROFILE_DIR}" -maxdepth 1 -type f -name "*.json*" -delete 2>/dev/null || true
    find "${FIREFOX_PROFILE_DIR}" -maxdepth 1 -type f -name "*.sqlite" -delete 2>/dev/null || true
    rm -rf "${FIREFOX_PROFILE_DIR}/storage" 2>/dev/null || true
    rm -rf "${FIREFOX_PROFILE_DIR}/indexedDB" 2>/dev/null || true
    rm -rf "${FIREFOX_PROFILE_DIR}/bookmarkbackups" 2>/dev/null || true
    rm -f "${FIREFOX_PROFILE_DIR}/prefs.js" 2>/dev/null || true
    rm -f "${FIREFOX_PROFILE_DIR}/user.js" 2>/dev/null || true
    
    # 复制备份的配置文件
    echo "   📋 Copying profile data..."
    cp -r "${BACKUP_DATA}/firefox_profile"/* "${FIREFOX_PROFILE_DIR}/" 2>/dev/null || true
    
    echo "   ✅ Firefox profile restored"
else
    echo "⚠️  No Firefox profile found in backup"
fi

# 恢复下载文件
if [ -d "${BACKUP_DATA}/downloads" ]; then
    echo "2️⃣  Restoring downloads..."
    mkdir -p "${DATA_DIR}/downloads"
    rsync -a "${BACKUP_DATA}/downloads/" "${DATA_DIR}/downloads/" 2>/dev/null || true
    echo "   ✅ Downloads restored: $(find "${DATA_DIR}/downloads" -type f | wc -l) files"
else
    echo "⚠️  No downloads found in backup"
fi

# 恢复书签
if [ -d "${BACKUP_DATA}/bookmarks" ]; then
    echo "3️⃣  Restoring bookmarks..."
    mkdir -p "${DATA_DIR}/bookmarks"
    cp -r "${BACKUP_DATA}/bookmarks"/* "${DATA_DIR}/bookmarks/" 2>/dev/null || true
    echo "   ✅ Bookmarks restored"
else
    echo "⚠️  No bookmarks found in backup"
fi

# 设置权限
echo "4️⃣  Setting permissions..."
chmod -R 777 "${DATA_DIR}" 2>/dev/null || true

# 清理临时目录
echo "5️⃣  Cleaning up..."
rm -rf "${RESTORE_DIR}"

# 显示结果
echo ""
echo "================================================================================"
echo "✅ Restore completed successfully!"
echo "================================================================================"
echo ""
echo "📊 Restore Summary:"
echo "   📁 Source: ${BACKUP_FILE}"
echo "   🎯 Target: ${DATA_DIR}"
echo "   ⏰ Completed: $(date)"
echo ""
echo "🚀 Next steps:"
echo "   1. The container needs to be restarted for changes to take effect"
echo "   2. Firefox will start with restored data on next launch"
echo ""
echo "🔄 To restart the container:"
echo "   docker restart <container_name>"
echo ""
echo "📝 Note: Original data was backed up to ${CURRENT_BACKUP}"
echo "================================================================================"

# 建议重启
echo ""
echo "💡 Recommendation: Restart the container now to apply changes"