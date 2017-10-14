# cicd-howto
# steps to replicate the CI/CD environment
Notes regarding how we setup the CICD

Components:
  MariaDB
  Zookeeper
  Zuul v3
  Nodepool v3
  DiskImage Builder
  Kolla

Change to root directory:
cd /root

Add bubblewrap ppa:
apt install software-properties-common python-software-properties

add-apt-repository ppa:openstack-ci-core/bubblewrap

apt update

Run package upgrade:
apt update && apt upgrade -y

Install MariaDB and Zookeeper:
apt install mariadb-server mariadb-client

wget http://apache.mirrors.ionfish.org/zookeeper/current/zookeeper-3.4.10.tar.gz

cat << EOF > /root/mysql_secure_installation.sql
UPDATE mysql.user SET Password=PASSWORD('root') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

mysql -sfu root < "mysql_secure_installation.sql"

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

Install Zuul and Nodepool:
git clone https://github.com/openstack-infra/zuul -b feature/zuulv3

git clone https://github.com/openstack-infra/nodepool -b feature/zuulv3

cd zuul
pip install .

mkdir -p /etc/zuul/status
mkdir /etc/nodepool
mkdir /var/log/zuul

# You need to update the '{{ public_address }}' below
cat << EOF > /etc/zuul/zuul.conf
[gearman]
server=127.0.0.1
;port=4730
;ssl_ca=/path/to/ca.pem
;ssl_cert=/path/to/client.pem
;ssl_key=/path/to/client.key

[zookeeper]
hosts=zuul.local

[gearman_server]
start=true
;ssl_ca=/path/to/ca.pem
;ssl_cert=/path/to/server.pem
;ssl_key=/path/to/server.key
;port=4730

[scheduler]
tenant_config=/etc/zuul/main.yaml
log_config=/etc/zuul/logging.conf
pidfile=/var/run/zuul/zuul.pid
state_dir=/var/lib/zuul

;[merger]
;git_dir=/var/lib/zuul/git
;git_user_email=zuul@example.com
;git_user_name=zuul

[executor]
user=root
trusted_ro_paths=/opt/zuul-scripts:/var/cache
trusted_rw_paths=/opt/zuul-logs

[web]
listen_address=0.0.0.0
port=9000

[webapp]
listen_address=0.0.0.0
port=8001
status_url=http://{{ public_address }}/status

[connection github]
driver=github
server=github.com
;baseurl=https://review.example.com/r
;baseurl=http://{{ public address }}/r
;user=zuul
;sshkey=/home/zuul/.ssh/id_rsa
;keepalive=60
api_token={{ github_token }}
webhook_token={{ webhook_token }}
verify_ssl=false

[connection smtp]
driver=smtp
server=localhost
port=25
default_from=zuul@zuul.local
default_to=nulledinbox@gmail.com

[connection mydatabase]
driver=sql
dburi=mysql+pymysql://zuul:zuul@localhost/zuul
EOF

cat << EOF > /etc/zuul/main.yaml
- tenant:
    name: openlab
    source:
      github:
        config-projects:
          - theopenlab/project-config
        untrusted-projects:
          # Order matters, load common job repos first
          - theopenlab/zuul-jobs:
              shadow: theopenlab/project-config
          #- openstack-infra/openstack-zuul-jobs
          #- openstack-infra/openstack-zuul-roles
          # devstack-gate, devsack and tempest all define things expected
          # to be widely used.
          #- openstack-infra/devstack-gate
          #- openstack-dev/devstack
          #- openstack/tempest
          # After this point, sorting projects alphabetically will help
          # merge conflicts
          - theopenlab/gophercloud
          - theopenlab/cicd
EOF

cat << EOF > /etc/zuul/logging.conf
[loggers]
keys=root,zuul,gerrit

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
level=DEBUG
handlers=debug,normal
qualname=gerrit

[handler_console]
level=WARNING
class=StreamHandler
formatter=simple
args=(sys.stdout,)

[handler_debug]
level=DEBUG
class=logging.handlers.TimedRotatingFileHandler
formatter=simple
args=('/var/log/zuul/debug.log', 'midnight', 1, 30,)

[handler_normal]
level=INFO
class=logging.handlers.TimedRotatingFileHandler
formatter=simple
args=('/var/log/zuul/zuul.log', 'midnight', 1, 30,)

[formatter_simple]
format=%(asctime)s %(levelname)s %(name)s: %(message)s
datefmt=
EOF
