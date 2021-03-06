#!/bin/bash

# Author: DC
# Initialize and install eirods iCAT server

# Check if a package is installed, add it to a installing 
# list if it is not installed
#
# $1 - package full name
is_installed(){ 
	PKG_NAME=$(echo $1|cut -d'.' -f1)
	PKG_SEARCH_RESULT=$(yum search $PKG_NAME|grep "^$1")
	if [  "$(echo $PKG_SEARCH_RESULT|grep "No matches found")" ];then
		echo "$1 not found in yum repo. Check your yum repo."
		echo "Installation failed."
		exit 1
	fi
		PKG_SEARCH_RESULT=$(echo $PKG_SEARCH_RESULT|awk '{print $1}')
		echo "$PKG_SEARCH_RESULT is found in the repo."
		DEP_PKGS="$DEP_PKGS $PKG_SEARCH_RESULT"

}

# Check dist
if [ ! "$(grep "CentOS" /etc/redhat-release|egrep "5\.[0-9]{1}")" ];then
	echo "This script is for CentOS 5.x."
	echo "Exit."
	exit 1
fi

# ID of the process occupying port 5432, which will be used by PostgreSQL
LISTEN_PID=$(netstat -ntlp|grep 5432|awk '{print $7}'|cut -d'/' -f1 2> /dev/null)

# IP of the machine
IPADDR=$(ifconfig eth0|grep 'inet addr'|cut -d':' -f2|cut -d' ' -f1|sed 's/[ \t]//g')
HOSTNAME="icat-$(echo $IPADDR|cut -d'.' -f1)$(echo $IPADDR|cut -d'.' -f4)"
ICAT_DOWNLOAD="ftp://ftp.renci.org/pub/eirods/releases/3.0/eirods-3.0-64bit-icat-postgres-redhat.rpm"
ICAT_PATH="/root/build/eirods-3.0-64bit-icat-postgres-redhat.rpm"

echo "Remove user eirods..."
userdel eirods 2> /dev/null
echo "Remove legacy data..."
rm -rf /var/lib/pgsql/data

if [ "$LISTEN_PID" ];then
	echo "Stop service listening port 5432..."
	kill -9 $LISTEN_PID
fi

echo "Set hostname..."
hostname $HOSTNAME
if [ ! "$(grep $IPADDR /etc/hosts)" ];then
	sed -i "/icat.*/d" /etc/hosts
	echo "$IPADDR $HOSTNAME" >> /etc/hosts
fi
sed -i "s/HOSTNAME.*/HOSTNAME=$HOSTNAME/g" /etc/sysconfig/network
echo "Restart network.."
/sbin/service network restart

is_installed authd.x86_64
is_installed unixODBC.x86_64
is_installed perl.x86_64
is_installed postgresql-server.x86_64
is_installed postgresql.x86_64
is_installed postgresql-odbc.x86_64

DEP_PKGS=$(echo $DEP_PKGS|sed "s/^ //g")
if [ "$DEP_PKGS" ];then
	echo "$DEP_PKGS will be installed."
	yum install -y $DEP_PKGS
fi

echo "Change /etc/xinetd.d/auth and start xinetd..."
sed -i "s/--os -E/--os/g" /etc/xinetd.d/auth
/sbin/chkconfig --level=3 auth on
if [ ! "$(/sbin/service xinetd status|grep running)" ];then
	/etc/init.d/xinetd start
else
	echo "Xinetd is running."
fi
 
echo "Initialize and start PostgreSQL..."
if [ ! "$(/sbin/service postgresql status|grep running)" ];then
	/etc/init.d/postgresql start
else
	echo "PostgreSQL is running."
fi

if ! [ -a $ICAT_PATH ];then
	echo "Download eirods iCAT installation package..."
	mkdir -p /root/build
	wget $ICAT_DOWNLOAD -P /root/build
fi

if [ -a $ICAT_PATH ];then
	rpm -i /root/build/eirods-3.0-64bit-icat-postgres-redhat.rpm
else
	echo "iCAT installation package not found.Exit."
	echo "Installation failed."
	exit 1
fi

echo "Completed!"
su eirods

exit 0
