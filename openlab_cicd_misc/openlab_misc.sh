#!/bin/bash -x

# Change to root directory
if [[ $EUID -ne 0 ]]; then
    echo "You should run this script as root."
    exit 1
fi

if [[ -z "$ZUUL_IP" ]]; then
    echo "The ZUUL_IP must be set."
    exit 1
fi

cdir=$(cd $(dirname "$0") && pwd)

cd /root

# Add zuul user
useradd -m -d /home/zuul -s /bin/bash zuul
echo zuul:zuul | chpasswd

# Add log server dir
mkdir -p /srv/static/logs/
chown zuul.zuul /srv/static/logs/ -R

# Precondition
apt update -y && apt upgrade -y
apt install python python-pip python3 python3-pip default-jdk python-psycopg2 -y

# Install apache2
apt-get install apache2 -y
apt-get install libapache2-mod-wsgi -y

# Install graphite, carbon
apt install mariadb-server mariadb-client python-pymysql -y

cat << EOF > /root/mysql_secure_installation.sql
UPDATE mysql.user SET Password=PASSWORD('root') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
CREATE USER 'graphite'@'localhost' IDENTIFIED BY 'password';
CREATE DATABASE IF NOT EXISTS graphite;
GRANT ALL PRIVILEGES ON graphite.* TO 'graphite'@'localhost' IDENTIFIED BY 'password';
FLUSH PRIVILEGES;
EOF
mysql -sfu root < mysql_secure_installation.sql

DEBIAN_FRONTEND=noninteractive apt-get install graphite-web graphite-carbon -y
cp $cdir/conf/graphite/local_settings.py /etc/graphite/
cp $cdir/conf/carbon/*.conf /etc/carbon/
cp $cdir/conf/graphite/apache2-graphite.conf /etc/apache2/sites-available/
cp $cdir/conf/apache2-common/ports.conf /etc/apache2/
graphite-manage migrate auth
graphite-manage syncdb --noinput

# Install grafana
cd ~
wget https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana_4.5.2_amd64.deb
sudo apt-get install -y adduser libfontconfig
sudo dpkg -i grafana_4.5.2_amd64.deb
cp $cdir/conf/grafana/* /etc/grafana/
service grafana-server restart

# install statsd
apt-get install git nodejs devscripts debhelper dh-systemd -y
apt-get install npm -f -y
mkdir ~/build
cd ~/build
git clone https://github.com/etsy/statsd.git
cd statsd
dpkg-buildpackage
cd .. 
cp $cdir/conf/statsd/* /etc/statsd/
sudo service carbon-cache stop
sudo dpkg -i statsd*.deb
service carbon-cache start
service statsd restart

# Install zuul status
cp $cdir/conf/zuul/zuul-web.conf /etc/apache2/sites-available/
git clone git://git.openstack.org/openstack-infra/zuul /root/zuul -b feature/zuulv3
mkdir -p /var/www/zuul-web
mkdir -p /etc/zuul/
DEST_DIR=/root/zuul/zuul/web/static/

mkdir -p $DEST_DIR/js
curl -L --silent https://ajax.googleapis.com/ajax/libs/angularjs/1.5.6/angular.min.js > $DEST_DIR/js/angular.min.js
curl -L --silent http://code.jquery.com/jquery.min.js > $DEST_DIR/js/jquery.min.js
curl -L --silent https://raw.githubusercontent.com/mathiasbynens/jquery-visibility/master/jquery-visibility.js > $DEST_DIR/js/jquery-visibility.js
python2 -mrjsmin < $DEST_DIR/js/jquery-visibility.js > $DEST_DIR/js/jquery-visibility.min.js
curl -L --silent https://github.com/twbs/bootstrap/releases/download/v3.1.1/bootstrap-3.1.1-dist.zip > bootstrap.zip
unzip -q -o bootstrap.zip -d $DEST_DIR/
mv $DEST_DIR/bootstrap-3.1.1-dist $DEST_DIR/bootstrap
rm -f bootstrap.zip
curl -L --silent https://github.com/prestontimmons/graphitejs/archive/master.zip > jquery-graphite.zip
unzip -q -o jquery-graphite.zip -d $DEST_DIR/
python2 -mrjsmin < $DEST_DIR/graphitejs-master/jquery.graphite.js > $DEST_DIR/js/jquery.graphite.min.js
rm -Rf jquery-graphite.zip $DEST_DIR/graphitejs-master

pip3 install -r /root/zuul/requirements.txt
pip3 install pymysql
pip3 install -e /root/zuul
cp -r /root/zuul/zuul/web/static/* /var/www/zuul-web/
cp $cdir/conf/zuul/zuul.conf /etc/zuul/
cp $cdir/conf/zuul/web-logging.conf /etc/zuul/
sed -i s/zuul-server-ip/${ZUUL_IP}/g /etc/zuul/zuul.conf
mkdir -p /var/log/zuul/
/usr/bin/python3 /usr/local/bin/zuul-web -d > /dev/null 2>1 &
#htpasswd -cbB /etc/apache2/grafana_htpasswd openlab openlab

sudo service carbon-cache stop
service carbon-cache start
service statsd restart
service grafana-server restart

# Configure apache security
DEBIAN_FRONTEND=noninteractive apt-get install libapache2-mod-evasive libapache2-modsecurity -y
mv /etc/modsecurity/modsecurity.conf{-recommended,}
sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/g' /etc/modsecurity/modsecurity.conf
mkdir -p /var/log/mod_evasive
a2enmod evasive
a2enmod security2
cp $cdir/conf/mod_evasive/evasive.conf /etc/apache2/mods-available/

apt-get install fail2ban -y
cp $cdir/conf/fail2ban/jail.local /etc/fail2ban/jail.local
cp $cdir/conf/fail2ban/apache-modsecurity.conf /etc/fail2ban/filter.d/
service fail2ban restart

a2dissite 000-default
a2ensite apache2-graphite
a2ensite zuul-web
a2enmod proxy
a2enmod proxy_http
a2enmod ssl
a2enmod xml2enc
a2enmod rewrite
a2enmod headers
a2enmod proxy_wstunnel
service apache2 restart
