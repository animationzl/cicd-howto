#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "You should run this script as root."
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

mkdir -p /etc/nodepool/elements
mkdir -p /var/log/nodepool
mkdir -p /opt/dib_tmp
mkdir -p /opt/dib_cache
mkdir -p /etc/openstack

TOP_DIR=$(cd $(dirname "$0") && pwd)
PREFIX_DIR=/etc/nodepool

for config in $(ls $TOP_DIR/$PREFIX_DIR)
do
    envsubst < "$TOP_DIR/$PREFIX_DIR/$config" > "$PREFIX_DIR/$config"
done

PREFIX_DIR=/etc/openstack
config=clouds.yaml
envsubst < "$TOP_DIR/$PREFIX_DIR/$config" > "$PREFIX_DIR/$config"

# Install dependencies
apt update && apt upgrade -y
apt install python python-pip python3 python3-pip -y
apt install kpartx qemu-utils curl python-yaml debootstrap -y

# Sync openstack custom elements
cd /root
git clone https://github.com/openstack-infra/project-config
cd project-config
rsync -avz nodepool/elements/ /etc/nodepool/elements/

# Install DiskImage Builder
cd /root
git clone https://github.com/openstack/diskimage-builder
cd diskimage-builder
pip install -r requirements.txt
pip install -e .

# Install Nodepool v3
cd /root
git clone https://github.com/openstack-infra/nodepool -b feature/zuulv3
cd nodepool
pip3 install -r requirements.txt
pip3 install -e .
