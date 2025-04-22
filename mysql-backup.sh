#!/bin/bash
# 备份docker容器中的mysql指定数据库到宿主机，并且只保留最近7天的备份数据，设置定时任务每天凌晨0点执行备份

# 判断脚本输入参数是否为空
if [ $# -ne 1 ]; then
    echo "Usage: sh $0 <db_name>"
    exit 1
fi

# MySQL 认证信息
DB_USER="root"
DB_PASS="QdJv2iojuW@jtzl"

# 备份目录
BACKUP_DIR="/home/mysql/backup"

# 判断备份目录是否存在，如果不存在则创建
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

# 当前时间
DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H-%M-%S")

for DB_NAME in `docker exec -it mysql sh -c "mysql -uroot -pQdJv2iojuW@jtzl -e 'show databases like \"$1%\";'" |grep -vE "Database|-|Warning" |awk -F "[ |]" '{print $3}'`;do
echo $DB_NAME

# 备份文件名称
BACKUP_FILE="$DB_NAME-$DATE-$TIME.sql"

# 备份数据库到容器/tmp目录
docker exec -it mysql sh -c "mysqldump -u $DB_USER -p$DB_PASS $DB_NAME > /tmp/$BACKUP_FILE"

# 从容器/tmp目录复制备份文件到宿主机备份目录
docker cp mysql:/tmp/$BACKUP_FILE $BACKUP_DIR/$BACKUP_FILE
# 删除容器/tmp目录中的备份文件
docker exec -it mysql sh -c "rm -rf /tmp/$BACKUP_FILE"
# 输出备份完成信息
echo "Backup completed: $BACKUP_DIR/$BACKUP_FILE"

done

# 删除主机上超过7天的备份文件
find $BACKUP_DIR -type f -mtime +7 -exec rm {} \;

