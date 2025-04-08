#!/bin/bash

# 定义要检查的端口
PORTS=("80" "1883" "3306" "6379" "8080" "8128" "9092" "9093" "9100" "9200" "9505" "18083")

# 定义一个空数组用于存储被占用的端口
occupied_ports=()

# 检查端口是否被占用
for port in "${PORTS[@]}"; do
    if ss -tuln | grep -q ":$port "; then
        occupied_ports+=("$port")
    fi
done

# 检查是否安装了 Docker
if command -v docker &> /dev/null; then
    docker_status="Docker 已安装: "`docker --version`
else
    docker_status="Docker 未安装"
fi

# 检查是否安装了 Docker compose
if command -v docker compose &> /dev/null; then
    dockercompose_status="compose 已安装: "`docker compose version`
else
    dockercompose_status="Docker compose 未安装"
fi

# 检查防火墙状态
if systemctl is-active --quiet firewalld; then
    firewall_status="防火墙已启用"
    # 如果防火墙启用，输出防火墙规则
    firewall_rules=$(firewall-cmd --list-all)
elif  systemctl is-active iptables; then
    firewall_status="防火墙已启用"
    # 如果防火墙启用，输出防火墙规则
    firewall_rules=$(iptables -nL)
else
    firewall_status="防火墙未启用"
    firewall_rules=""
fi

# selinux状态
selinux=$(cat /etc/selinux/config |grep -Ev "^#|^$" |head -n 1)

# 检查系统最大可用分区
max_available_partition=$(df -h --output=avail,target | grep -vE '^Avail|tmpfs' | sort -rh | head -n 1)
max_partition_size=$(echo $max_available_partition | awk '{print $1}')
max_partition_mount=$(echo $max_available_partition | awk '{print $2}')

# 检查内存
max_mem=$(free -gh |grep "Mem" |awk '{print $2}')
available_mem=$(free -gh |grep "Mem" |awk '{print $NF}')

# 检查cpu
cpu_model=$(cat /proc/cpuinfo |grep "model name" |head -n 1|awk -F : '{print $NF}')
cpu_core=$(cat /proc/cpuinfo |grep "cpu cores" |head -n 1|awk '{print $NF}')
cpu_sibling=$(cat /proc/cpuinfo |grep "siblings" |head -n 1|awk '{print $NF}')

# 输出结果
echo "===== 检查结果 ====="
if [ ${#occupied_ports[@]} -gt 0 ]; then
    echo "被占用的端口: ${occupied_ports[@]}"
else
    echo "没有系统部署需要的端口被占用"
fi
echo "$docker_status"
echo "$dockercompose_status"
echo "$firewall_status"
echo "$firewall_rules"
echo "$selinux"
echo "分区情况："
echo "    最大分区: $max_partition_mount"
echo "    可用空间: $max_partition_size"
echo "内存情况："
echo "    总内存: $max_mem"
echo "    剩余内存: $available_mem"
echo "CPU:"
echo "    型号": $cpu_model
echo "    核数": $cpu_core
echo "    线程数": $cpu_sibling