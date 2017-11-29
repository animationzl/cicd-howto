#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "You should run this script as root."
    exit 1
fi

# Add user zuul if not exits
if ! id -u zuul > /dev/null 2>&1; then
    useradd -m -d /home/zuul -s /bin/bash zuul
    echo zuul:zuul | chpasswd
fi

# Generate ssh key
su - zuul -c "
ssh-keygen -f /home/zuul/.ssh/id_rsa -t rsa -N ''
"

mkdir -p /etc/zuul
mkdir -p /var/log/zuul
mkdir -p /var/lib/zuul/builds
chown -R zuul:zuul /var/lib/zuul

TOP_DIR=$(cd $(dirname "$0") && pwd)
PREFIX_DIR=/etc/zuul
. $TOP_DIR/local-conf.sh

LOCAL_IP=$(ifconfig | awk '/inet addr/ {print substr($2, 6)}' | grep 192)
export GEARMAN_IP=${GEARMAN_IP:-$LOCAL_IP}
export STATSD_IP=${STATSD_IP:-$LOCAL_IP}
export ZOOKEEPER_IP=${ZOOKEEPER_IP:-$LOCAL_IP}
export WEB_LISTEN_IP=${WEB_LISTEN_IP:-$LOCAL_IP}
export APP_ID=${APP_ID:-}
export WEBHOOK_TOKEN=${WEBHOOK_TOKEN:-}

for config in $(ls $TOP_DIR/$PREFIX_DIR)
do
    envsubst < "$TOP_DIR/$PREFIX_DIR/$config" > "$PREFIX_DIR/$config"
done

# Install dependencies
apt update && apt upgrade -y
apt install python python-pip python3 python3-pip -y

# Install Zuul v3
cd /home/zuul
git clone https://github.com/openstack-infra/zuul -b feature/zuulv3
cd zuul
pip3 install -r requirements.txt
pip3 install -e .
