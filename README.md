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
# Add bubblewrap ppa
apt install software-properties-common python-software-properties

add-apt-repository ppa:openstack-ci-core/bubblewrap

apt update
```

```shell
# Run package upgrade
apt update && apt upgrade -y
```

```shell
# Install MariaDB and Zookeeper
apt install mariadb-server mariadb-client

wget http://apache.mirrors.ionfish.org/zookeeper/current/zookeeper-3.4.10.tar.gz

# you should consider changing the root password
cat << EOF > /root/mysql_secure_installation.sql
UPDATE mysql.user SET Password=PASSWORD('root') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

mysql -sfu root < "mysql_secure_installation.sql"

# you should consider changing the zuul password
cat << EOF > /root/zuul_db.sql
CREATE DATABASE zuul;
GRANT ALL PRIVILEGES ON zuul.* to 'zuul'@'localhost' IDENTIFIED BY 'zuul';
FLUSH PRIVILEGES;
EOF

mysql -sfu root < "zuul_db.sql"

tar xzf zookeeper-3.4.10.tar.gz

cat << EOF > /root/zookeeper-3.4.10/conf/zoo.cfg
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
EOF

/root/zookeeper-3.4.10/bin/zkServer.sh start
```

```shell
# Install DiskImage Builder
cd /root

git clone https://github.com/openstack/diskimage-builder
git clone https://github.com/theopenlab/openlab-config

cd /root/diskimage-builder
pip install -e .

rsync -avz /root/diskimage-builder/diskimage-builder/elements/ /etc/nodepool/elements/
rsync -avz /root/openlab-config/elements /etc/nodepool/elements/
```

```shell
# Install Zuul and Nodepool
mkdir /etc/zuul
mkdir /etc/nodepool
mkdir /var/log/zuul
mkdir /var/log/nodepool
mkdir /opt/zuul-scripts
mkdir /opt/zuul-logs

cd /root

git clone https://github.com/openstack-infra/zuul -b feature/zuulv3

git clone https://github.com/openstack-infra/nodepool -b feature/zuulv3

cd /root/zuul
pip install -e .

cd /root/nodepool
pip install -e .

# bash heredocs for zuul configuration
https://gist.github.com/mrhillsman/f2f7867ad3ab2399f16d9efc7ffe4ec3

# bash heredocs for nodepool configuration
https://gist.github.com/mrhillsman/766dc50b9bf42cd81c71f9e18e841b41
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
