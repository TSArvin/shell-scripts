#!/bin/bash

# 检查是否提供了数据库名参数
if [ $# -eq  ]; then
    echo "错误: 请指定要备份的数据库名"
    echo "用法: $0 <数据库名>"
    exit 1
fi

# 配置参数
CONTAINER_NAME="mysql"        # MySQL容器名称
MYSQL_USER="root"            # MySQL用户名
MYSQL_PASSWORD="QdJv2iojuW@jtzl"    # MySQL密码
DATABASE_NAME="$1"           # 通过参数传递的数据库名
BACKUP_DIR="/home/mysql_backup/data" # 宿主机备份目录
DATE=$(date +%Y%m%d_%H%M%S)  # 当前时间格式
TEMP_FILE="/tmp/${DATABASE_NAME}_${DATE}.sql" # 容器内临时文件路径
LOG_DIR="/home/mysql_backup/log"

# 创建备份目录（如果不存在）
mkdir -p $BACKUP_DIR
mkdir -p $LOG_DIR

# 检查数据库是否存在
DB_EXISTS=$(docker exec $CONTAINER_NAME mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES LIKE '$DATABASE_NAME';" | grep -o $DATABASE_NAME)

if [ -z "$DB_EXISTS" ]; then
    echo "错误: 数据库 $DATABASE_NAME 不存在" | tee -a $LOG_DIR/log_$DATE.log
    exit 1
fi

# 记录开始时间
echo "$(date '+%Y-%m-%d %H:%M:%S') 开始备份数据库: $DATABASE_NAME" | tee -a $LOG_DIR/log_$DATE.log

# 1. 在容器内执行备份（添加--verbose输出进度）
docker exec $CONTAINER_NAME bash -c "mysqldump -u$MYSQL_USER -p$MYSQL_PASSWORD --verbose $DATABASE_NAME > $TEMP_FILE"

# 检查备份是否成功
BACKUP_STATUS=$?
if [ $BACKUP_STATUS -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') 错误: 数据库 $DATABASE_NAME 备份失败，状态码: $BACKUP_STATUS" | tee -a $LOG_DIR/log_$DATE.log
    exit 1
fi

# 2. 检查备份文件是否已完全生成
echo "$(date '+%Y-%m-%d %H:%M:%S') 验证容器内备份文件..." | tee -a $LOG_DIR/log_$DATE.log
docker exec $CONTAINER_NAME bash -c "test -f $TEMP_FILE && echo '备份文件存在' || echo '备份文件不存在'"
FILE_EXISTS=$?
if [ $FILE_EXISTS -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') 错误: 容器内备份文件未生成" | tee -a $LOG_DIR/log_$DATE.log
    exit 1
fi

# 3. 将备份文件从容器复制到宿主机
echo "$(date '+%Y-%m-%d %H:%M:%S') 开始拷贝备份文件到宿主机..." | tee -a $LOG_DIR/log_$DATE.log
docker cp $CONTAINER_NAME:$TEMP_FILE $BACKUP_DIR/

# 检查拷贝是否成功
COPY_STATUS=$?
if [ $COPY_STATUS -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') 错误: 备份文件拷贝失败，状态码: $COPY_STATUS" | tee -a $LOG_DIR/log_$DATE.log
    exit 1
fi

# 4. 验证宿主机上的备份文件
echo "$(date '+%Y-%m-%d %H:%M:%S') 验证宿主机上的备份文件..." | tee -a $LOG_DIR/log_$DATE.log
if [ ! -f "$BACKUP_DIR/${DATABASE_NAME}_${DATE}.sql" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') 错误: 宿主机上未找到备份文件" | tee -a $LOG_DIR/log_$DATE.log
    exit 1
fi

# 5. 删除容器内的备份文件
echo "$(date '+%Y-%m-%d %H:%M:%S') 删除容器内的临时备份文件..." | tee -a $LOG_DIR/log_$DATE.log
docker exec $CONTAINER_NAME rm -f $TEMP_FILE

# 6. 压缩备份文件
echo "$(date '+%Y-%m-%d %H:%M:%S') 开始压缩备份文件..." | tee -a $LOG_DIR/log_$DATE.log
gzip $BACKUP_DIR/${DATABASE_NAME}_${DATE}.sql

# 检查压缩是否成功
GZIP_STATUS=$?
if [ $GZIP_STATUS -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') 警告: 备份文件压缩失败，状态码: $GZIP_STATUS" | tee -a $LOG_DIR/log_$DATE.log
fi

# 7. 删除超过30天的备份
echo "$(date '+%Y-%m-%d %H:%M:%S') 清理30天前的旧备份..." | tee -a $LOG_DIR/log_$DATE.log
find $BACKUP_DIR -name "${DATABASE_NAME}_*.sql.gz" -type f -mtime +30 -delete

echo "$(date '+%Y-%m-%d %H:%M:%S') 备份成功完成: ${DATABASE_NAME}_${DATE}.sql.gz" | tee -a $LOG_DIR/log_$DATE.log
