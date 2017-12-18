#!/bin/bash -x

CHDIR=$(cd $(dirname "$0") && pwd)
FIXED_IP=$(ifconfig | awk '/inet addr/ {print substr($2, 6)}' | grep 192)

source $CHDIR/allinone/allinonerc
mv /etc/apt/sources.list /etc/apt/sources.list-bak
cp $CHDIR/allinone/sources.list /etc/apt/

$CHDIR/openlab_cicd_misc/gearman_zookeeper.sh

$CHDIR/sync-sshkey.sh
$CHDIR/nodepool.sh
$CHDIR/zuulv3.sh

cp $CHDIR/allinone/main.yaml /etc/zuul/
cp $CHDIR/allinone/nodepool.yaml /etc/nodepool/

$CHDIR/openlab_cicd_misc/openlab_misc.sh

cp $CHDIR/allinone/zuul.yaml /etc/zuul/

/usr/bin/python3 /usr/local/bin/nodepool-builder -d -l /etc/nodepool/builder-logging.conf -c /etc/nodepool/nodepool.yaml > /dev/null 2>1 &
/usr/bin/python3 /usr/local/bin/nodepool-launcher -d -l /etc/nodepool/launcher-logging.conf -c /etc/nodepool/nodepool.yaml > /dev/null 2>1 &
/usr/bin/python3 /usr/local/bin/zuul-executor -d --keep-jobdir > /dev/null 2>1 &
/usr/bin/python3 /usr/local/bin/zuul-scheduler -d > /dev/null 2>1 &
/usr/bin/python3 /usr/local/bin/zuul-merger -d > /dev/null 2>1 &
