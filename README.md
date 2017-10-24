# OpenLab CI/CD
_steps to replicate the CI/CD environment_

## Components Required
  _MariaDB_  
  _Zookeeper_  
  _Zuul v3_  
  _Nodepool v3_  
  _DiskImage Builder_  
  _Kolla_  

## Step-by-step (all-in-one)

```shell
# Change to root directory
cd /root
```

```shell
# Precondition
apt update -y && apt upgrade -y
apt install python python-pip python3 python3-pip default-jdk -y
```

```shell
# Install bubblewrap
apt install software-properties-common
add-apt-repository ppa:openstack-ci-core/bubblewrap -y
apt update -y
apt install bubblewrap -y
```

```shell
# Install MariaDB
apt install mariadb-server mariadb-client -y

# You should consider changing the root password
cat << EOF > /root/mysql_secure_installation.sql
UPDATE mysql.user SET Password=PASSWORD('root') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

mysql -sfu root < mysql_secure_installation.sql
```

```shell
# Install Zookeeper
wget http://apache.mirrors.ionfish.org/zookeeper/current/zookeeper-3.4.10.tar.gz
tar xzf zookeeper-3.4.10.tar.gz

cat << EOF > /root/zookeeper-3.4.10/conf/zoo.cfg
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
EOF

# Start Zookeeper
/root/zookeeper-3.4.10/bin/zkServer.sh start
```

```shell
# Install Zuul v3

# Add zuul user
useradd -m -d /home/zuul -s /bin/bash zuul
# You should consider changing the zuul password
echo zuul:zuul | chpasswd

# Generate ssh key then add the public key to your github account
sudo su - zuul -c "
ssh-keygen -f /home/zuul/.ssh/id_rsa -t rsa -N ''
"

mkdir -p /etc/zuul
mkdir -p /var/log/zuul
mkdir -p /var/lib/zuul
mkdir -p /var/lib/zuul/git
mkdir -p /var/lib/zuul/builds
chown -R zuul:zuul /var/lib/zuul

git clone https://github.com/openstack-infra/zuul -b feature/zuulv3 /home/zuul/zuul
chown -R zuul:zuul /home/zuul
cd /home/zuul/zuul
apt install python3-crypto -y
pip3 install -r requirements.txt
pip3 install -e .

FIXED_IP=
FLOATING_IP=
GIT_USER_EMAIL=
GIT_USER_NAME=
API_TOKEN=
WEBHOOK_TOKEN=
GIT_ACCOUNT=

cat << EOF > /etc/zuul/zuul.conf
[gearman]
server=$FIXED_IP
check_job_registration=true
;ssl_ca=/etc/zuul/ssl/ca.pem
;ssl_cert=/etc/zuul/ssl/client.pem
;ssl_key=/etc/zuul/ssl/client.key

[gearman_server]
start=true
log_config=/etc/zuul/gearman-logging.conf
;ssl_ca=/etc/zuul/ssl/ca.pem
;ssl_cert=/etc/zuul/ssl/server.pem
;ssl_key=/etc/zuul/ssl/server.key

[statsd]
server=$FIXED_IP
;port=

[scheduler]
tenant_config=/etc/zuul/main.yaml
log_config=/etc/zuul/scheduler-logging.conf
state_dir=/var/lib/zuul

[webapp]
status_url=http://$FLOATING_IP/

[zookeeper]
hosts=$FIXED_IP
;session_timeout=

[merger]
git_dir=/var/lib/zuul/git
;zuul_url=
log_config=/etc/zuul/merger-logging.conf
git_user_email=$GIT_USER_EMAIL
git_user_name=$GIT_USER_NAME

[executor]
log_config=/etc/zuul/executor-logging.conf
job_dir=/var/lib/zuul/builds
;variables=/etc/zuul/site-variables.yaml
private_key_file=/home/zuul/.ssh/id_rsa
;trusted_ro_dirs=
;trusted_rw_dirs=
;untrusted_ro_dirs=
;untrusted_rw_dirs=
;trusted_ro_paths=
;trusted_rw_paths=
;untrusted_ro_paths=
;untrusted_rw_paths=
;disk_limit_per_job=

[web]
log_config=/etc/zuul/web-logging.conf
listen_address=0.0.0.0
;listen_port=

[connection github]
driver=github
server=github.com
baseurl=http://$FLOATING_IP/
user=zuul
sshkey=/home/zuul/.ssh/id_rsa
;keepalive=60
api_token=$API_TOKEN
webhook_token=$WEBHOOK_TOKEN
verify_ssl=false

;[connection smtp]
;driver=smtp
;server=localhost
;port=25
;default_from=zuul@zuul.local
;default_to=randominbox@gmail.com

;[connection mydatabase]
;driver=sql
;dburi=mysql+pymysql://zuul:zuul@require.local/zuul
EOF

cat << EOF > /etc/zuul/main.yaml
- tenant:
    name: openlab
    source:
      github:
        config-projects:
          - $GIT_ACCOUNT/project-config
        untrusted-projects:
          # Order matters, load common job repos first
          - $GIT_ACCOUNT/zuul-jobs:
              shadow: $GIT_ACCOUNT/project-config
          - $GIT_ACCOUNT/gophercloud-jobs
          - openstack-infra/devstack-gate
          # After this point, sorting projects alphabetically will help
          # merge conflicts
          - $GIT_ACCOUNT/gophercloud
EOF

cat << EOF > /etc/zuul/scheduler-logging.conf
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
args=('/var/log/zuul/scheduler-debug.log',)

[handler_normal]
level=INFO
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/scheduler.log',)

[formatter_simple]
format=%(asctime)s %(levelname)s %(name)s: %(message)s
datefmt=
EOF

cat << EOF > /etc/zuul/executor-logging.conf
[loggers]
keys=root,zuul,gerrit,gear

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

[logger_gear]
level=WARNING
handlers=debug,normal
qualname=gear

[handler_console]
level=WARNING
class=StreamHandler
formatter=simple
args=(sys.stdout,)

[handler_debug]
level=DEBUG
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/executor-debug.log',)

[handler_normal]
level=INFO
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/executor.log',)

[formatter_simple]
format=%(asctime)s %(levelname)s %(name)s: %(message)s
datefmt=
EOF

cat << EOF > /etc/zuul/launcher-logging.conf
[loggers]
keys=root,zuul,gerrit,gear

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

[logger_gear]
level=WARNING
handlers=debug,normal
qualname=gear

[handler_console]
level=WARNING
class=StreamHandler
formatter=simple
args=(sys.stdout,)

[handler_debug]
level=DEBUG
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/launcher-debug.log',)

i[handler_normal]
level=INFO
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/launcher.log',)

[formatter_simple]
format=%(asctime)s %(levelname)s %(name)s: %(message)s
datefmt=
EOF

cat << EOF > /etc/zuul/merger-logging.conf
[loggers]
keys=root,zuul,gerrit,gear

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

[logger_gear]
level=WARNING
handlers=debug,normal
qualname=gear

[handler_console]
level=WARNING
class=StreamHandler
formatter=simple
args=(sys.stdout,)

[handler_debug]
level=DEBUG
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/merger-debug.log',)

[handler_normal]
level=INFO
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/merger.log',)

[formatter_simple]
format=%(asctime)s %(levelname)s %(name)s: %(message)s
datefmt=
EOF

cat << EOF > /etc/zuul/web-logging.conf
[loggers]
keys=root,zuul,gerrit,gear

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

[logger_gear]
level=WARNING
handlers=debug,normal
qualname=gear

[handler_console]
level=WARNING
class=StreamHandler
formatter=simple
args=(sys.stdout,)

[handler_debug]
level=DEBUG
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/web-debug.log',)

[handler_normal]
level=INFO
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/web.log',)

[formatter_simple]
format=%(asctime)s %(levelname)s %(name)s: %(message)s
datefmt=
EOF

cat << EOF > /etc/zuul/gearman-logging.conf
[loggers]
keys=root,zuul,gerrit,gear

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

[logger_gear]
level=WARNING
handlers=debug,normal
qualname=gear

[handler_console]
level=WARNING
class=StreamHandler
formatter=simple
args=(sys.stdout,)

[handler_debug]
level=DEBUG
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/gearman-debug.log',)

[handler_normal]
level=INFO
class=logging.handlers.WatchedFileHandler
formatter=simple
args=('/var/log/zuul/gearman.log',)

[formatter_simple]
format=%(asctime)s %(levelname)s %(name)s: %(message)s
datefmt=
EOF

# Add webhook in the github project to be managed
# Such as: http://$FLOATING_IP:8001/connection/github/payload

# Start Zuul
zuul-scheduler -d
zuul-executor -d
```

```shell
# Install DiskImage Builder
cd /root
git clone https://github.com/openstack/diskimage-builder
cd /root/diskimage-builder
pip install -r requirements.txt
pip install -e .

```

```shell
# Install Nodepool v3

mkdir -p /etc/nodepool
mkdir -p /etc/nodepool/elements
mkdir -p /var/log/nodepool
mkdir -p /opt/dib_tmp
mkdir -p /opt/dib_cache
mkdir -p /etc/openstack

# Sync openstack custom elements
cd /root
git clone https://github.com/openstack-infra/project-config
rsync -avz /root/project-config/nodepool/elements/ /etc/nodepool/elements/

cd /root
git clone https://github.com/openstack-infra/nodepool -b feature/zuulv3
cd /root/nodepool
apt install python3-netifaces -y
pip3 install -r requirements.txt
pip3 install -e .

NETWORKS=
KEYNAME=

cat << EOF > /etc/nodepool/nodepool.yaml
images-dir: /opt/dib_tmp
elements-dir: /etc/nodepool/elements

zookeeper-servers:
  - host: $FIXED_IP

diskimages:
  - name: ubuntu-xenial
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
  - name: ubuntu-xenial
    min-ready: 2

providers:
  - name: openlab
    cloud: openlab
    driver: openstack
    diskimages:
      - name: ubuntu-xenial
    pools:
      - name: openlab
        max-servers: 10
        networks:
          - $NETWORKS
        labels:
          - name: ubuntu-xenial
            diskimage: ubuntu-xenial
            flavor-name: 'c1.large'
            key-name: $KEYNAME

webapp:
  port: 8005
  listen_address: '0.0.0.0'
EOF

cat << EOF > /etc/nodepool/secure.conf
# Empty
EOF

cat << EOF > /etc/nodepool/builder-logging.conf
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
args=('/var/log/nodepool/nodepool-builder.log',)

[formatter_simple]
format=%(asctime)s %(levelname)s %(name)s: %(message)s
datefmt=
EOF

cat << EOF > /etc/nodepool/launcher-logging.conf
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
args=('/var/log/nodepool/nodepool-launcher.log',)

[formatter_simple]
format=%(asctime)s %(levelname)s %(name)s: %(message)s
datefmt=
EOF

# Repos to include for image building
cat << EOF > /etc/nodepool/repos.yaml
- project: openstack-infra/project-config
- project: openstack-infra/system-config
- project: openstack-dev/devstack
- project: openstack/tempest
- project: openstack/cinder
- project: openstack/glance
- project: openstack/horizon
- project: openstack/keystone
- project: openstack/neutron
- project: openstack/nova
EOF

# Put your openstack credentials in place
cat << EOF > /etc/openstack/clouds.yaml
iclouds:
  openlab:
    auth:
      username: ''
      password: ''
      project_id: ''
      auth_url: ''
      project_name: ''
      project_domain_name: ''
      user_domain_name: ''
    identity_api_version: ''
    network_api_version: ''
    volume_api_version: ''
    network_endpoint_override: ''
    regions:
    - name: eu-de
      values:
        networks:
          - name: $NETWORKS
            default_interface: true
EOF

# Start nodepool
apt install kpartx qemu-utils curl python-yaml debootstrap -y

nodepool-builder -d -l /etc/nodepool/builder-logging.conf -c /etc/nodepool/nodepool.yaml
nodepool-launcher -d -l /etc/nodepool/launcher-logging.conf -c /etc/nodepool/nodepool.yaml
```

### PoC - Install OpenStack via Kolla-Ansible
```shell
# multinode inventory file, globals.yaml, and passwords.yaml
# be sure to use kolla-ansible documentation to understand/edit
mkdir /etc/kolla

pip install kolla==4.0.2 # ocata
pip install kolla-ansible==4.0.2 # ocata

# generate /etc/kolla/passwords.yml
kolla-genpwd

https://gist.github.com/mrhillsman/be2d4968f8fb39ff2dd38d8e5b5c27e7


```

```shell
# put your openstack credentials in place
mkdir -p /root/.config/openstack

cat << EOF > /root/.config/openstack/clouds.yaml
clouds:
  openlab:
    auth:
      username: 'admin'
      password: 'Mc3ikupo'
      project_id: '16da6a0c93944eec9905cdab86ec92e6'
      auth_url: 'http://172.29.176.100:5000/v3'
      project_name: 'admin'
      project_domain_name: 'default'
      user_domain_name: 'default'
EOF
```

```shell
# start services

```

### Reference deployment view

```txt

                                     openlab status portal: http://80.158.20.68/
                                                +
                                                |
                                                |
                                                |
                                                |
                                                v

                                      openlab-cicd-misc
                                      +----------------------+                 github.com webhooks
                                      |       Apache2        |                        +
                                      |       Gearman        |                        |
                                      |       Zookeeper      |                        |
                                      |       Log-server     |                        |
                                      |       Statsd         |                        v
                                      +----------------------+
openlab-cicd-nodepool                                                          openlab-cicd-zuul
+----------------------+                  +              +                     +-----------------------+
|                      |                  |              |                     |                       |
|   Nodepool-launcher  |                  |              |                     |     Zuul-scheduler    |
|   Nodepool-builder   |  <---------------+              +------------------>  |     Zuul-executor     |
|                      |                                                       |     Zuul-web          |
+----------------------+                                                       |     Zuul-merger       |
                                                                               |                       |
           +                                                                   +-----------------------+
           |
           |  Launch vm from provider                                                 +
           |                                                                          |
           v                                                                          |
                                                                                      |
+----------------------+                                                              |
|                      |                     Execute Ansible jobs                     |
|                      |                                                              |
| Huawei public cloud  |  <-----------------------------------------------------------+
|                      |
|                      |
+----------------------+


```
