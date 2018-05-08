#!/bin/bash

echo "开始一键安装了哦"

#1. 系统环境设置

#1.1修改主机名
read -p "请输入主机名：" name                                        #输入新主机名
sed -i "2c HOSTNAME=${name}" /etc/sysconfig/network                  #修改主机名

#1.2修改IP地址
ETH0='/etc/sysconfig/network-scripts/ifcfg-eth0'                     #定义常量
read -p "输入IP地址：" IP                                            #输入新IP地址
sed -i "7a IPADDR=${IP}" ${ETH0}                                     #修改IP地址
read -p "输入子网掩码NETMASK：" NETMASK                              #输入新子网掩码
sed -i "8a NETMASK=${NETMASK}" ${ETH0}                               #修改子网掩码
read -p "输入网关GATEWAY地址：" GATEWAY                              #输入新网关
sed -i "9a GATEWAY=${GATEWAY}" ${ETH0}                               #修改网关

#1.3修改主机名和 IP 的映射关系
echo $IP $name >> /etc/hosts                                         #主机名与IP映射

#1.4 关闭防火墙
service iptables stop                                                #关闭防火墙
chkconfig iptables off                                               #关闭防火墙开机启动

#1.5将DHCP主动获取IP地址服务关闭
sed -i '/^BOOTPROTO/d' /etc/sysconfig/network-scripts/ifcfg-eth0     #将配置文件中DHCP自动获取IP地址的功能删除


#2. 安装 jdk
#2.1创建jdk和hadoop目录
mkdir /usr/lib/hadoop
mkdir /usr/lib/jdk

#2.2解压jdk和Hadoop
size=0
tail -c $size  install_hadoop.bin >all.tar.gz
tar -zxf all.tar.gz
cd all
tar -zxvf hadoop-2.6.0.tar.gz  -C /usr/lib/hadoop                    #将hadoop解压到创建的目录
tar -zxvf jdk-7u79-linux-x64.tar.gz  -C /usr/lib/jdk                 #将jdk解压到创建的目录

#2.3将java和hadoop添加到环境变量中
echo export JAVA_HOME=/usr/lib/jdk/jdk1.7.0_79 >>/etc/profile        #配置JAVA_HOME环境变量
echo export HADOOP_HOME=/usr/lib/hadoop/hadoop-2.6.0 >> /etc/profile #配置HADOOP_HOME环境变量
echo export PATH=$PATH:/usr/lib/hadoop/hadoop-2.6.0/bin:/usr/lib/hadoop/hadoop-2.6.0/sbin:/usr/lib/jdk/jdk1.7.0_79/bin >> /etc/profile   #配置JAVA和HADOOP的PATH变量
sed -i '$a # source /etc/profile' /etc/profile                       #文件末尾添加# source /etc/profile
sed -i '$a # java –version' /etc/profile                             #文件末尾添加# java –version
source /etc/profile

#3.配置 ssh 免登陆
(echo -e "\n"
sleep 1
echo -e "\n"
sleep 1
echo -e "\n"
sleep 1
echo -e "\n")|ssh-keygen -t rsa                                      #实现自动输入四个回车执行ssh-keygen -t rsa  命令
cat  ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys                     #将公钥拷贝到要免登陆的机器上

#4.1 配置 hadoop

#4.1.1 配置 hadoop-env.sh
sed -i "s/\${JAVA_HOME}/\/usr\/lib\/jdk\/jdk1.7.0_79/g"  /usr/lib/hadoop/hadoop-2.6.0/etc/hadoop/hadoop-env.sh                           #向配置文件添加内容

#4.1.2 配置 core-site.xml
sed -i '/<configuration>/a\\n\<property>\n\<name>fs.defaultFS</name>\n\<value>hdfs://h1m1:9000</value>\n\</property>\n\<property>\n\<name>hadoop.tmp.dir</name>\n\<value>/usr/lib/hadoop/tmp</value>\n\</property>\n\<property>\n\<name>io.file.buffer.size</name>\n\<value>4096</value>\n\</property>'  /usr/lib/hadoop/hadoop-2.6.0/etc/hadoop/core-site.xml

#4.1.3 配置 hdfs-site.xml
sed -i '/<configuration>/a\<property>\n\<name>dfs.replication</name>\n\<value>2</value>\n\</property>\n\<property>\n\<name>dfs.namenode.name.dir</name>\n\<value>file:///usr/lib/hadoop/dfs/name</value>\n\</property>\n\<property>\n\<name>dfs.datanode.data.dir</name>\n\<value>file:///usr/lib/hadoop/dfs/data</value>\n\</property>\n\<property>\n\<name>dfs.nameservices</name>\n\<value>h1</value>\n\</property>\n\<property>\n\<name>dfs.namenode.secondary.http-address</name>\n\<value>h1m1:50090</value>\n\</property>\n\<property>\n\<name>dfs.webhdfs.enabled</name>\n\<value>true</value>\n\</property>'   /usr/lib/hadoop/hadoop-2.6.0/etc/hadoop/hdfs-site.xml

#4.1.4 配置 mapred-site.xml  
cd /usr/lib/hadoop/hadoop-2.6.0/etc/hadoop                            #进入/usr/lib/hadoop/hadoop-2.6.0/etc/hadoop目录
cp mapred-site.xml.template mapred-site.xml                           #备份mapred-site.xml.template并命名为mapred-site.xml 
sed -i '/<configuration>/a\\n\<property>\n\<name>mapreduce.framework.name</name>\n\<value>yarn</value>\n\<final>true</final>\n\</property>\n\<property>\n\<name>mapreduce.jobtracker.http.address</name>\n\<value>h1m1:50030</value>\n\</property>\n\<property>\n\<name>mapreduce.jobhistory.address</name>\n\<value>h1m1:10020</value>\n\</property>\n\<property>\n\<name>mapreduce.jobhistory.webapp.address</name>\n\<value>h1m1:19888</value>\n\</property>\n\<property>\n\<name>mapred.job.tracker</name>\n\<value>http://h1m1:9001</value>\n\</property>'  /usr/lib/hadoop/hadoop-2.6.0/etc/hadoop/mapred-site.xml

#4.1.5 配置 yarn-site.xml
sed -i '/<configuration>/a\\n\<!-- Site specific YARN configuration properties -->\n\<property>\n\<name>yarn.resourcemanager.hostname</name>\n\<value>h1m1</value>\n\</property>\n\<property>\n\<name>yarn.nodemanager.aux-services</name>\n\<value>mapreduce_shuffle</value>\n\</property>\n\<property>\n\<name>yarn.resourcemanager.address</name>\n\<value>h1m1:8032</value>\n\</property>\n\<property>\n\<name>yarn.resourcemanager.scheduler.address</name>\n\<value>h1m1:8030</value>\n\</property>\n\<property>\n\<name>yarn.resourcemanager.resource-tracker.address</name>\n\<value>h1m1:8031</value>\n\</property>\n\<property>\n\<name>yarn.resourcemanager.admin.address</name>\n\<value>h1m1:8033</value>\n\</property>\n\<property>\n\<name>yarn.resourcemanager.webapp.address</name>\n\<value>h1m1:8088</value>\n\</property>'  /usr/lib/hadoop/hadoop-2.6.0/etc/hadoop/yarn-site.xml

#4.2 配置jdk时已经将 hadoop 添加到环境变量  

#4.3 格式化 namenode
echo "hadoop安装完成,开始格式化"
cd /usr/lib/hadoop/hadoop-2.6.0/bin                                    #进入/usr/lib/hadoop/hadoop-2.6.0/bin目录
hadoop namenode -format                                                #格式化namenode
echo "安装完成开始重启"


#5.重启
echo "系统配置已经更改，需要重启生效"                                  #实现用户根据需要自行选择重启
read -p "输入y立即重启，输入n退出自行选择重启时间：" a
b="y"
if [ "$a" = "$b" ];then
reboot
else  exit
fi

