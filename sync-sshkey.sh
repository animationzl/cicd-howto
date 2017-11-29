#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "You should run this script as root."
    exit 1
fi

TOP_DIR=$(cd $(dirname "$0") && pwd)
. $TOP_DIR/local-conf.sh

LOCAL_IP=$(ifconfig | awk '/inet addr/ {print substr($2, 6)}' | grep 192)
ZUUL_IP=${ZUUL_IP:-$LOCAL_IP}
NODEPOOL_IP=${NODEPOOL_IP:-$LOCAL_IP}
LOGSERVER_IP=${LOGSERVER_IP:-$LOCAL_IP}

if [ -z "$OPENLAB_CICD_PEM" ]; then
    echo 'You must specify the pem file directory in OPENLAB_CICD_PEM.'
    exit 1
fi

# Add user zuul and generate ssh key if not exits
if ! id -u zuul > /dev/null 2>&1; then
    useradd -m -d /home/zuul -s /bin/bash zuul
    echo zuul:zuul | chpasswd
    su - zuul -c "
        ssh-keygen -f /home/zuul/.ssh/id_rsa -t rsa -N ''
        cat /home/zuul/.ssh/id_rsa.pub > /home/zuul/.ssh/authorized_keys
    "
fi

for host in $ZUUL_IP $NODEPOOL_IP $LOGSERVER_IP
do
    [[ "$host" == "$LOCAL_IP" ]] && continue
    rsync -a -e "ssh -i $OPENLAB_CICD_PEM -o StrictHostKeyChecking=no" --rsync-path 'sudo rsync' \
        /home/zuul/.ssh/ ubuntu@$host:/home/zuul/.ssh/
done
