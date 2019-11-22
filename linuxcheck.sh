#!/bin/bash


cat << EOF
0.检测命令是否被修改
1.获取网络连接
2.查看对外开放端口
3.查看是否存在高危端口
4.查看启动项
5.查看定时任务
6.查看调度任务
7.检测cpu异常进程
8.检测特权用户
9.查看登陆用户
10.可登录用户
11.最近修改过的文件
12.查看是否存在可疑命令
13.root是否允许远程登陆
14.检查是否存在可疑脚本
15.日志文件打包
16.查看登陆到主机的用户
17.检查磁盘使用量
EOF


date=$(date +%Y%m%d)
check_file="tee -a $(mkdir /tmp/check_file_$(date +%s))/checkfile.txt"
log_file="tee -a $(mkdir /tmp/log_file_$(date +%s))/logfile.txt"

if [ $(whoami) != "root" ]; then
    echo -e "\e[1;31m 请以root权限运行 \e[0m"
    exit
fi

echo "以下运行需要系统存在ps,netstat,systemctl命令，如果由于系统差异造成没有命令请手动安装。" && read -p "确认已存在[Y/N] >" name
if [ $name != 'Y' ];then
    exit 1
fi

echo --------------0.检测命令是否被修改---------
year=$(stat /bin/ps | grep Change | awk '{print $2}' | awk -F- '{print $1}')
mouth=$(stat /bin/ps | grep Change | awk '{print $2}' | awk -F- '{print $2}')
day=$(stat /bin/ps | grep Change | awk '{print $2}' | awk -F- '{print $3}')
if [ $year -eq $(date +%Y) ];then
    if [ $mouth -eq $(date +%m) ];then
        if [ $day -eq $(date +%d) ];then
            echo -e "\e[1;31m ps命令被修改，请手动查看命令是否正常！\e[0m"
        else
            vul=`expr $(date +%d) - $day`
            if [[ $vul -le 5 ]];then
                echo -e "\e[1;31m ps命令最近被修改，请手动查看命令是否正常！\e[0m"
            fi
            echo -e "\e[1;32m ps命令最近五天内没有修改！\e[0m"
        fi
    else
        echo -e "\e[1;32m ps命令最近月内没有修改！\e[0m"
    fi
else
    echo -e "\e[1;32m ps命令今年内没有修改！\e[0m"
fi

year=$(stat /bin/netstat | grep Change | awk '{print $2}' | awk -F- '{print $1}')
mouth=$(stat /bin/netstat | grep Change | awk '{print $2}' | awk -F- '{print $2}')
day=$(stat /bin/netstat | grep Change | awk '{print $2}' | awk -F- '{print $3}')
if [ $year -eq $(date +%Y) ];then
    if [ $mouth -eq $(date +%m) ];then
        if [ $day -eq $(date +%d) ];then
            echo -e "\e[1;31m netstat命令被修改，请手动查看命令是否正常！\e[0m"
        else
            vul=`expr $(date +%d) - $day`
            if [[ $vul -le 5 ]];then
                echo -e "\e[1;31m netstat命令最近被修改，请手动查看命令是否正常！\e[0m"
            fi
            echo -e "\e[1;32m netstat命令最近五天内没有修改！\e[0m"
        fi
    else
        echo -e "\e[1;32m netstat命令最近月内没有修改！\e[0m"
    fi
else
    echo -e "\e[1;32m netstat命令今年内没有修改！\e[0m"
fi


echo --------------1.获取网络连接---------------
pspid=$(netstat -antp | grep 'ESTABLISHED \| SYN_SENT \|SYN_RECEIVED' | awk '{print $7}'|cut -d "/" -f 1)
for pid in $pspid; do
    dir=$(lsof -p $pid | awk '{print $9}')
    echo "\e[1;31m 网络连接pid对应文件：\n ${dir}" | ${check_file}
    printf "\n" | ${check_file}
done

echo --------------2.查看对外开放端口------------
listport=$(netstat -anltp | grep LISTEN | awk '{print $4,$7}'|sed 's/:/ /g' | awk '{print $2,$3}' | sed 's/\// /g'|awk '{print $1,$3}'|sort |uniq)
if [ -n "$listport" ]; then
    echo -e "\e[1;31m 系统开放的端口和对应的服务为：\n $listport \e[0m"  | ${check_file}
    printf "\n" | ${check_file}
fi

echo --------------3.查看是否存在高危端口---------
dangerport=$(netstat -anltp | awk '{print $4}'|sed 's/:/ /g'|awk '{print $2}'|sort |uniq)
for i in $(cat danger.port);do
    port=$($i | awk -F: '{print $1}')
    desc=$($i | awk -F: '{print $2}')
    process=$( $i | awk -F: '{print $3}')
    if [[ $dangerport =~ $port ]];then
        echo -e "\e[1;31m 存在高危端口${port},病毒类型${desc},病毒进程名${process}" | ${check_file}
        printf "\n" | ${check_file}
    fi
done

echo ---------------4.查看启动项------------------
enables=$(systemctl list-unit-files | grep enabled | awk '{print $1}')
if [ -n $enables ];then
    echo -e "\e[1;31m 系统自启动项为以下：${enables}\e[0m"  | ${check_file}
    printf "\n" | ${check_file}
else
    echo -e "\e[1;32m 系统没有自启动项！\e[0m"
fi

echo ---------------5.查看定时任务-----------------
crontab=$(cat /etc/crontab | grep "run-parts")
if [ -n "$crontab" ];then
    echo -e "\e[1;31m 系统定时任务为：\n${crontab}\e[0m"  |  ${check_file}
    printf "\n" | ${check_file}
else
    echo -e "\e[1;32m 系统不存在定时任务！\e[0m"
fi

echo ---------------6.查看调度任务------------------
cron=$(crontab -l)
if [ -n "$cron" ];then
    echo -e "\e[1;31m 调度任务为：\n ${cron} \e[0m"  |  ${check_file}
    printf "\n" | ${check_file}
else
    echo -e "\e[1;32m 没有调度任务。\e[0m"
fi

echo ---------------7.检测cpu异常进程---------------
processpid=$(ps -aux | awk 'NR!=1{print $2,$3}' | sed 's/\./ /g'|awk '{print $1,$2}')
echo -e "\e[1;32m cpu占用前五的进程：\n $(ps -aux | sort -nr -k 3 | head -5) \e[0m" | ${check_file}
printf "\n" | ${check_file}
if [ -n "$processpid" ];then
    for i in "$processpid";do
        if [ $(echo $i | awk '{print $2}') -gt 20 ];then
            echo -e "\e[1;31m 异常进程的pid为：\n $(echo $i|awk '{print $1}')\e[0m" | ${check_file}
            printf "\n" | ${check_file}
        fi
    done
    echo -e "\e[1;32m 如需要查看进程文件请查看log日志！\e[0m"
    ps -aux | ${log_file}
    printf "\n" | ${log_file}
fi

echo ---------------8.检测特权用户------------------
uiduser=$(awk -F: '$3==0{print $1}' /etc/passwd | grep -v root)
giduser=$(awk -F: '$4==0{print $1}' /etc/passwd | grep -v root)
lenuser=$(awk -F: 'length($2)==0 {print $1}' /etc/shadow)
nopasswd=$(awk -F: '{if($2!="x") {print $1}}' /etc/passwd)
if [ $uiduser ];then
    echo -e "\e[1;31m 存在UID为0的特权用户为：\n ${uiduser} \e[0m"  | ${check_file}
    printf "\n"| ${check_file}
fi
if [ $giduser ];then
    echo -e "\e[1;31m 存在GID为0的特权账户为：\n ${giduser} \e[0m"  | ${check_file}
    printf "\n"| ${check_file}
fi
if [ $lenuser ];then
    echo -e "\e[1;31m 存在登陆口令为空的账户为：\n ${lenuser} \e[0m" | ${check_file}
    printf "\n"| ${check_file}
fi
if [ $nopasswd ];then
    echo -e "\e[1;31m 存在未加密用户账号为：\n ${nopasswd} \e[0m" | ${check_file}
    printf "\n"| ${check_file}
fi

echo ---------------9.查看登陆用户------------------
echo -e "\e[1;31m 正在登陆的用户有：\n $(who)" | ${check_file}
printf "\n" | ${check_file}

echo ---------------10.可登录用户-------------------
loginuser=$(cat /etc/passwd | grep -E "/bin/bash$" | awk -F: '{print $1}')
if [ -n "$loginuser" ];then
    echo -e "\e[1;31m 可登录的用户有：\n ${loginuser} \e[0m" | ${check_file}
    printf "\n" | ${check_file}
fi

echo ---------------11.最近修改过的文件---------------
changefile=$(find / -ctime 5)
if [ -n "$changefile" ];then
    echo -e "\e[1;31m 最近修改过的文件有：\n ${changefile} \e[0m" | ${check_file}
    printf "\n" | ${check_file}
fi

echo ---------------12.查看是否存在可疑命令-------------
command=$(history | grep -E "(wget|curl|nc|nmap|\.sh|useradd|adduser|userdel|passwd)")
if [ -n "$command" ];then
    echo -e "\e[1;31m 存在以下可疑的操作命令: ${command}\e[0m" | ${check_file}
    printf "\n" | ${check_file}
fi

echo ----------------13.root是否允许远程登陆------------
root=$(cat /etc/ssh/sshd_config |grep -v ^# | grep "PermitRootLogin yes")
if [ -n "$root" ];then
    echo -e "\e[1;31m 允许root远程登陆 \e[0m" | ${check_file}
    printf "\n" | ${check_file}
fi

echo ----------------14.检查是否存在可疑脚本-------------
script=$(find / *.* | grep "\.(py|sh|per|pl)$"| grep -v "/usr|/etc|/var")
if [ -n "$script" ];then
    echo -e "\e[1;31m 发现存在以下脚本文件${script} \e[0m" | ${check_file}
    printf "\n" | ${check_file}
fi

echo ----------------15.日志文件打包--------------------
echo -e "\e[1;32m 正在打包日志......\e[0m"
tar -czf /tmp/system_log.tar.gz /var/log/
if [ $? -eq 0 ]; then
    echo -e "\e[1;32m 日志打包成功 \e[0m"
else
    echo -e "\e[1;31m 日志打包失败 \e[0m"
fi

echo ----------------16.查看登陆到主机的用户---------------
last=$(last)
lastlog=$(lastlog)
echo -e "\e[1;32m 登陆到主机的用户: \n${last} \e[0m" | ${check_file}
printf "\n" | ${check_file}
if [ -n "$lastlog" ];then
    echo -e "\e[1;32m 登陆到主机的全部用户: \n${lastlog} \e[0m" | ${check_file}
    printf "\n" | ${check_file}
fi

echo ----------------17.检查磁盘使用量---------------------
df=$(df -h | awk 'NR!=1{print $1,$5}'|awk '{print $1,$2}'|awk -F% '{print $1,$2}')
for i in "$df";do
    dir=$(echo $i|awk '{print $1}')
    percen=$(echo $i|awk '{print $2}')
    if [ "$percen" -ge 40 ]; then
        echo -e "\e[1;31m 磁盘分区${dir}占用量过高 \e[0m" | ${check_file}
        printf "\n" | ${check_file}
    fi
done
