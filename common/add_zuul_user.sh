#!/bin/bash

# Add user zuul and generate ssh key if not exits
if ! id -u zuul > /dev/null 2>&1; then
    useradd -m -d /home/zuul -s /bin/bash zuul
    echo zuul:zuul | chpasswd
    su - zuul -c "
        ssh-keygen -f /home/zuul/.ssh/id_rsa -t rsa -N ''
        cat /home/zuul/.ssh/id_rsa.pub > /home/zuul/.ssh/authorized_keys
    "
else
    echo "zuul user already exist!"
fi
