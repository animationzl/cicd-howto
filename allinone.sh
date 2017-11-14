Fixed_IP=$(ifconfig | awk '/inet addr/ {print substr($2, 6)}' | grep 192)
TENANT=allinone
GIT_ACCOUNT=xxx
GIT_USER_EMAIL=xxx
GIT_USER_NAME=xxx
API_TOKEN=xxx
WEBHOOK_TOKEN=xxx
NETWORK=xxx
PROVIDER=$TENANT
IMAGE_NAME=ubuntu-xenial-$PROVIDER

# Precondition
apt update && apt upgrade -y

apt install python python-pip python3 python3-pip default-jdk -y
apt install kpartx qemu-utils curl python-yaml debootstrap -y
apt install python3-crypto -y
apt install python3-netifaces -y

apt install software-properties-common -y
add-apt-repository ppa:openstack-ci-core/bubblewrap -y
apt update
apt install bubblewrap -y

# Add user zuul
useradd -m -d /home/zuul -s /bin/bash zuul
echo zuul:zuul | chpasswd

# Generate ssh key then add the public key to your github account
sudo su - zuul -c "
ssh-keygen -f /home/zuul/.ssh/id_rsa -t rsa -N ''
"

mkdir -p /etc/zuul
mkdir -p /var/log/zuul
mkdir -p /var/lib/zuul
mkdir -p /var/lib/zuul/builds
chown -R zuul:zuul /var/lib/zuul

mkdir -p /etc/nodepool
mkdir -p /etc/nodepool/elements
mkdir -p /var/log/nodepool
mkdir -p /opt/dib_tmp
mkdir -p /opt/dib_cache
mkdir -p /etc/openstack

# Install Zookeeper
cd /root
wget http://apache.mirrors.ionfish.org/zookeeper/current/zookeeper-3.4.10.tar.gz
tar xzf zookeeper-3.4.10.tar.gz

cat << EOF > /root/zookeeper-3.4.10/conf/zoo.cfg
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
EOF

# Install Zuul v3
cd /home/zuul
git clone https://github.com/openstack-infra/zuul -b feature/zuulv3
cd zuul
pip3 install -r requirements.txt
pip3 install -e .

cat << EOF > /etc/zuul/zuul.conf
[gearman]
server=$Fixed_IP
check_job_registration=true

[gearman_server]
start=true
log_config=/etc/zuul/gearman-logging.conf

[zookeeper]
hosts=$Fixed_IP

[scheduler]
tenant_config=/etc/zuul/main.yaml
log_config=/etc/zuul/scheduler-logging.conf
state_dir=/var/lib/zuul

[executor]
log_config=/etc/zuul/executor-logging.conf
job_dir=/var/lib/zuul/builds
private_key_file=/home/zuul/.ssh/id_rsa

[merger]
git_user_email=$GIT_USER_EMAIL
git_user_name=$GIT_USER_NAME

[connection github]
driver=github
server=github.com
sshkey=/home/zuul/.ssh/id_rsa
api_token=$API_TOKEN
webhook_token=$WEBHOOK_TOKEN
verify_ssl=false
EOF

cat << EOF > /etc/zuul/main.yaml
- tenant:
    name: $TENANT
    source:
      github:
        config-projects:
          - $GIT_ACCOUNT/project-config
        untrusted-projects:
          - $GIT_ACCOUNT/zuul-jobs:
              shadow: $GIT_ACCOUNT/project-config
          - $GIT_ACCOUNT/openlab-zuul-jobs
          - openstack-infra/devstack-gate
          # custom repos
          - $GIT_ACCOUNT/gophercloud
EOF

for component in scheduler executor gearman
do

cat << EOF > /etc/zuul/$component-logging.conf
[loggers]
keys=root,zuul,gerrit,gerrit_io,gear,kazoo

[handlers]
keys=console,debug,normal

[formatters]
keys=simple

[logger_root]
level=WARNING
handlers=console

[logger_zuul]
level=DEBUG
handlers=debug,normal
qualname=zuul

[logger_gerrit]
level=INFO
handlers=debug,normal
qualname=gerrit

[logger_gerrit_io]
level=INFO
handlers=debug,normal
qualname=zuul.GerritConnection.io

[logger_gear]
level=WARNING
handlers=debug,normal
qualname=gear

[logger_kazoo]
level=INFO
handlers=debug,normal
qualname=kazoo

[handler_console]
level=WARNING
class=StreamHandler
formatter=simple
args=(sys.stdout,)

[handler_debug]
level=DEBUG
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/$component-debug.log',)

[handler_normal]
level=INFO
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/$component.log',)

[formatter_simple]
format=%(asctime)s %(levelname)s %(name)s: %(message)s
datefmt=
EOF

done

# Install DiskImage Builder
cd /root
git clone https://github.com/openstack/diskimage-builder
cd diskimage-builder
pip install -r requirements.txt
pip install -e .

# Sync openstack custom elements
cd /root
git clone https://github.com/openstack-infra/project-config
rsync -avz /root/project-config/nodepool/elements/ /etc/nodepool/elements/

# Install Nodepool v3
cd /root
git clone https://github.com/openstack-infra/nodepool -b feature/zuulv3
cd nodepool
pip3 install -r requirements.txt
pip3 install -e .

cat << EOF > /etc/nodepool/nodepool.yaml
images-dir: /opt/dib_tmp
elements-dir: /etc/nodepool/elements

zookeeper-servers:
  - host: $Fixed_IP

diskimages:
  - name: $IMAGE_NAME
    elements:
      - ubuntu
      - vm
      - simple-init
      - nodepool-base
      - cache-devstack
      - initialize-urandom
      - growroot
      - infra-package-needs
    release: xenial
    env-vars:
      TMPDIR: /opt/dib_tmp
      DIB_CHECKSUM: '1'
      DIB_IMAGE_CACHE: /opt/dib_cache
      DIB_APT_LOCAL_CACHE: '0'
      DIB_DISABLE_APT_CLEANUP: '1'
      DIB_GRUB_TIMEOUT: '0'
      DIB_DEBIAN_COMPONENTS: 'main,universe'
      DIB_CUSTOM_PROJECTS_LIST_URL: 'file:///etc/nodepool/repos.yaml'
      DIB_DEV_USER_PWDLESS_SUDO: '1'
      DIB_CLOUD_INIT_DATASOURCES: 'OpenStack'
      ZUUL_USER_SSH_PUBLIC_KEY: '/home/zuul/.ssh/id_rsa.pub'

labels:
  - name: $IMAGE_NAME
    min-ready: 2

providers:
  - name: $PROVIDER
    cloud: $TENANT
    driver: openstack
    diskimages:
      - name: $IMAGE_NAME
    pools:
      - name: openlab
        max-servers: 5
        networks:
          - $NETWORK
        labels:
          - name: $IMAGE_NAME
            diskimage: $IMAGE_NAME
            flavor-name: 'c2.xlarge'
EOF

cat << EOF > /etc/nodepool/secure.conf
# Empty
EOF

for component in builder launcher
do

cat << EOF > /etc/nodepool/$component-logging.conf
[loggers]
keys=root,nodepool,requests,shade

[handlers]
keys=console,normal

[formatters]
keys=simple

[logger_root]
level=WARNING
handlers=console

[logger_requests]
level=WARNING
handlers=normal
qualname=requests

[logger_shade]
level=WARNING
handlers=normal
qualname=shade

[logger_gear]
level=DEBUG
handlers=normal
qualname=gear

[logger_nodepool]
level=DEBUG
handlers=normal
qualname=nodepool

[handler_console]
level=WARNING
class=StreamHandler
formatter=simple
args=(sys.stdout,)

[handler_normal]
level=DEBUG
class=FileHandler
formatter=simple
args=('/var/log/nodepool/$component.log',)

[formatter_simple]
format=%(asctime)s %(levelname)s %(name)s: %(message)s
datefmt=
EOF

done

# Repos to include for image building
cat << EOF > /etc/nodepool/repos.yaml
- project: openstack-infra/project-config
- project: openstack-dev/devstack
- project: openstack-infra/devstack-gate
- project: openstack-infra/tripleo-ci
- project: openstack/ceilometer
- project: openstack/ceilometermiddleware
- project: openstack/cinder
- project: openstack/django_openstack_auth
- project: openstack/glance
- project: openstack/glance_store
- project: openstack/heat
- project: openstack/heat-cfntools
- project: openstack/heat-templates
- project: openstack/horizon
- project: openstack/keystone
- project: openstack/keystoneauth
- project: openstack/keystonemiddleware
- project: openstack/manila
- project: openstack/manila-ui
- project: openstack/neutron
- project: openstack/neutron-fwaas
- project: openstack/neutron-lbaas
- project: openstack/neutron-vpnaas
- project: openstack/nova
- project: openstack/octavia
- project: openstack/os-apply-config
- project: openstack/os-brick
- project: openstack/os-client-config
- project: openstack/os-collect-config
- project: openstack/os-net-config
- project: openstack/os-refresh-config
- project: openstack/osc-lib
- project: openstack/requirements
- project: openstack/swift
- project: openstack/tempest
- project: openstack/tempest-lib
- project: openstack/tripleo-heat-templates
- project: openstack/tripleo-image-elements
- project: openstack/tripleo-incubator
- project: openstack/zaqar
EOF

# Put your openstack credentials in place
cat << EOF > /etc/openstack/clouds.yaml
clouds:
  $TENANT:
    auth:
      username: 'xxx'
      password: 'xxx'
      project_id: 'xxx'
      auth_url: 'xxx'
      project_name: 'xxx'
      project_domain_name: 'xxx'
      user_domain_name: 'xxx'
    identity_api_version: '3'
    network_api_version: '2.0'
    volume_api_version: '2'
    network_endpoint_override: 'xxx'
    regions:
      - name: xxx
        values:
          networks:
            - name: $NETWORK
              default_interface: true
EOF

# Start services manually after integrate with github
# /root/zookeeper-3.4.10/bin/zkServer.sh start
# nohup nodepool-builder -d -l /etc/nodepool/builder-logging.conf -c /etc/nodepool/nodepool.yaml > /dev/null 2>&1 &
# nohup nodepool-launcher -d -l /etc/nodepool/launcher-logging.conf -c /etc/nodepool/nodepool.yaml > /dev/null 2>&1 &
# nohup zuul-scheduler -d > /dev/null 2>&1 &
# nohup zuul-executor -d --keep-jobdir > /dev/null 2>&1 &
