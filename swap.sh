#!/bin/bash
# 必须以 root 执行
# 1. 极度激进的 Swap 策略：1GB 物理内存不够 Chrome 启动两个标签页。
# 创建 2GB Swap 文件，尽量防止 OOM Killer 杀掉容器。
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# 2. 网络拥塞控制算法优化 (BBR)
# 针对高延迟环境，BBR 能显著提高吞吐量。
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

# 3. 内存子系统调优
# vm.swappiness=100: 积极使用 Swap，把宝贵的物理 RAM 留给当前活跃的页面。
# vm.vfs_cache_pressure=50: 减少文件系统缓存回收，优先回收匿名页。
sysctl -w vm.swappiness=100
sysctl -w vm.vfs_cache_pressure=50
sysctl -p