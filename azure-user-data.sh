 #!/bin/bash
 yum update -y && \
 yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y && \
        yum install epel-release -y && \
        yum install libpmem-devel-1.1-1.el7.x86_64 -y && \
        yum install wget curl jq fio iperf3 sysbench -y \
        yum remove epel-release -y