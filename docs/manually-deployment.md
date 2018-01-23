# Guide of manually deployment OpenLab CI

```shell
# Commands need to be executed first on every node

# Clone and cd into repo
cd /root
git clone http://github.com/theopenlab/cicd-howto
cd cicd-howto

# Configure and export the variables
vim local.rc
source local.rc
```

```shell
# Execute following commands on the zuul node

# Install zuul
bash -x zuul/zuul.sh
```

```shell
# Execute following commands on the nodepool node

# Install nodepool
bash -x nodepool/nodepool.sh

# Sync ssh keys of zuul user
bash -x common/sync-sshkey.sh

# Add ssh public key of zuul user to git_user_name specified in merger section of /root/cicd-howto/etc/zuul/zuul.conf
```

```shell
# Execute following commands on the misc node

# Install gearman and zookeeper
bash -x misc/gearman_zookeeper.sh

# Install apache related services
bash -x misc/openlab_misc.sh
```

```shell
# Update secrets.yaml in theopenlab/project-config manually
```

```shell
# Start zuul,nodepool services on corresponding node
```
