# OpenLab CI/CD
_steps to replicate the CI/CD environment_

## Reference deployment view

```txt

                                     openlab status portal: http://status.openlabtesting.org/
                                                +
                                                |
                                                |
                                                |
                                                |
                                                v

                                      openlab-cicd-misc
                                      +----------------------+                 github.com events
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

## Step-by-step

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

# Install zuulv3
bash -x zuulv3.sh
```

```shell
# Execute following commands on the nodepool node

# Install nodepool
bash -x nodepool.sh

# Sync ssh keys of zuul user
bash -x sync-sshkey.sh

# Add ssh public key of zuul user to git_user_name specified in merger section of /root/cicd-howto/etc/zuul/zuul.conf
```

```shell
# Execute following commands on the misc node

# Install gearman and zookeeper
bash -x openlab_cicd_misc/gearman_zookeeper.sh

# Install apache related services
bash -x openlab_cicd_misc/openlab_misc.sh
```

```shell
# Update secrets.yaml in theopenlab/project-config manually
```

```shell
# Start zuul,nodepool services on corresponding node
```

## Connect to OpenLab

- Step 1: OpenLab maintainer will commit an issue to target project that plan to connect OpenLab, let target project maintainers know what we want to do, and discuss some details, looks like: [gophercloud Issue 592](https://github.com/gophercloud/gophercloud/issues/592)
- Step 2: If the above issue is approved, OpenLab maintainer will commit a pull request to target project, **.zuul.yaml** will be included in PR, that define which CI jobs will run, looks like: [gophercloud PR 593](https://github.com/gophercloud/gophercloud/pull/593)
- Step 3: Target project maintainer should install **TheOpenLab-CI** [github APP](https://github.com/apps/theopenlab-ci), so that OpenLab CI system and target project can communicate with each other, **TheOpenLab-CI** github APP only require basic permissions to update check status and commit test result log URL in PR comments, you can see permission details in APP installation web page.
