# Overview of The OpenLab CI architecture

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
|       Provider       |  <-----------------------------------------------------------+
|  (vm, bm, container) |
|                      |
+----------------------+


```
