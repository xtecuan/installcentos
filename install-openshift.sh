#!/bin/bash

## see: https://www.youtube.com/watch?v=-OOnGK-XeVY

DOMAIN=${DOMAIN:="$(curl ipinfo.io/ip).nip.io"}
USERNAME=${USERNAME:="$(whoami)"}
PASSWORD=${PASSWORD:=password}

SCRIPT_REPO=${SCRIPT_REPO:="http://github.com/gshipley/installcentos"}

echo "******"
echo "* Your domain is $DOMAIN "
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "******"

yum install -y epel-release

yum install -y git wget zile nano net-tools docker \
python-cryptography pyOpenSSL.x86_64 python2-pip \
openssl-devel python-devel httpd-tools NetworkManager python-passlib \
java-1.8.0-openjdk-headless "@Development Tools"

systemctl | grep "NetworkManager.*running" 
if [ $? -eq 1 ]; then
	systemctl start NetworkManager
	systemctl enable NetworkManager
fi

which ansible || pip install -Iv ansible

[ ! -d openshift-ansible ] && git clone http://github.com/openshift/openshift-ansible

cd openshift-ansible && git fetch && git checkout release-3.7 && cd ..

[ ! -d installcentos ] && git clone $SCRIPT_REPO

cat <<EOD > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 console console.${DOMAIN} $(hostname)
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOD

if [ -z $DISK ]; then 
	echo "Not setting the Docker storage."
else
	echo DEVS=$DISK >> /etc/sysconfig/docker-storage-setup
	echo VG=DOCKER >> /etc/sysconfig/docker-storage-setup
	echo SETUP_LVM_THIN_POOL=yes >> /etc/sysconfig/docker-storage-setup
	echo DATA_SIZE="100%FREE" >> /etc/sysconfig/docker-storage-setup

	systemctl stop docker

	rm -rf /var/lib/docker
	wipefs --all $DISK
	docker-storage-setup
fi

systemctl restart docker
systemctl enable docker

if [ ! -f ~/.ssh/id_rsa ]; then
	ssh-keygen -q -f ~/.ssh/id_rsa -N ""
	cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
	ssh -o StrictHostKeyChecking=no root@127.0.0.1 "pwd" < /dev/null
fi

METRICS="True"
LOGGING="True"

memory=$(cat /proc/meminfo | grep MemTotal | sed "s/MemTotal:[ ]*\([0-9]*\) kB/\1/")

if [ "$memory" -lt "4194304" ]; then
	METRICS="False"
fi

if [ "$memory" -lt "8388608" ]; then
	LOGGING="False"
fi

envsubst < installcentos/inventory.ini > inventory.ini
ansible-playbook -i inventory.ini openshift-ansible/playbooks/byo/config.yml

htpasswd -b /etc/origin/master/htpasswd ${USERNAME} ${PASSWORD}
oc adm policy add-cluster-role-to-user cluster-admin ${USERNAME}

echo "******"
echo "* Your conosle is https://console.$DOMAIN:8443"
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "*"
echo "* Login using:"
echo "*"
echo "$ oc login -u ${USERNAME} -p ${PASSWORD} https://console.$DOMAIN:8443/"
echo "******"

oc login -u ${USERNAME} -p ${PASSWORD} https://console.$DOMAIN:8443/
