# Guide of the "misc" node deployment

This guide will show you about how to deploy status web page of The OpenLab CI,
and the CI monitoring utils which include the grafana web page, graphite,
zookeeper, gearman and statd.

## Steps to deploy "misc" node

1. run `gearman_zookeeper.sh` script.

2. run `openlab_misc.sh` script with `ZUUL_IP` environment variable set.
