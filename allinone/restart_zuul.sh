#!/bin/bash

if [ ! -d "/var/run/zuul/" ]; then
    mkdir -p /var/run/zuul/
fi

for bin in "executor" "merger" "scheduler" "web"
do
    for pid in `ps -ef |grep /usr/local/bin/zuul-$bin |grep -v grep | awk '{print $2}'`
    do
        kill -9 $pid
    done
    rm /var/run/zuul/$bin.pid -fr
done

sleep 3

for bin in "executor" "merger" "scheduler" "web"
do
    
    rm /var/run/zuul/$bin.pid -fr
    if [ "$bin" = "executor" ]; then
        /usr/bin/python3 /usr/local/bin/zuul-$bin --keep-jobdir
        continue
    fi
    if [ "$bin" = "web" ]; then
        sleep 5
    fi
    /usr/bin/python3 /usr/local/bin/zuul-$bin
    sleep 2
done
