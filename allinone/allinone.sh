#!/bin/bash -x

CHDIR=$(cd $(dirname "$0") && pwd)/..
FIXED_IP=$(ifconfig | awk '/inet addr/ {print substr($2, 6)}' | grep 192)

source $CHDIR/allinone/allinonerc
mv /etc/apt/sources.list /etc/apt/sources.list-bak
cp $CHDIR/allinone/sources.list /etc/apt/

$CHDIR/misc/gearman_zookeeper.sh

$CHDIR/common/sync-sshkey.sh
$CHDIR/nodepool/nodepool.sh
$CHDIR/zuul/zuul.sh

cp $CHDIR/allinone/main.yaml /etc/zuul/
envsubst < $CHDIR/allinone/nodepool.yaml > /etc/nodepool/nodepool.yaml

$CHDIR/misc/openlab_misc.sh

envsubst < $CHDIR/zuul/conf/zuul.conf > /etc/zuul/zuul.conf
cat << EOF >> /etc/zuul/zuul.conf
[connection mysql]
driver=sql
dburi=mysql+pymysql://zuul:zuul@127.0.0.1/zuul
EOF

/usr/bin/python3 /usr/local/bin/nodepool-builder -d -l /etc/nodepool/builder-logging.conf -c /etc/nodepool/nodepool.yaml > /dev/null 2>1 &
/usr/bin/python3 /usr/local/bin/nodepool-launcher -d -l /etc/nodepool/launcher-logging.conf -c /etc/nodepool/nodepool.yaml > /dev/null 2>1 &

