#!/usr/bin/env bash
#
#
# A simple benchmark script to test your Disk, Network and CPU performance
# Forked from https://github.com/iandk/sysperf
#
# https://upcloud.com/community/stories/evaluating-cloud-server-performance-with-sysbench/

# Split JSON array into separate files/objects
# https://stackoverflow.com/questions/48790861/split-json-array-into-separate-files-objects
# jq -cn --stream 'fromstream(1|truncate_stream(inputs))' bigfile.json | split -l $num_of_elements_in_a_file - big_part

# ioping
# https://www.systutorials.com/docs/linux/man/1-ioping/

### DEBUG ONLY
#set -x

### Exit when any command returns a failure status.
#set -e

DATE=$( date +"%C%y%m%d_%H%M%S" )

RESULT_OUT=Perf_Benchmarking.json

PROJECT_PATH=$1
cd $PROJECT_PATH

set -o allexport; source ./.env; set +o allexport

FIO_BENCH_MOUNTPOINT=/data/$DATE


#
#
# VALIDATION
#
#

# Check if at least Redhat 7.9 is used
if grep -qs "redhat" /etc/os-release; then
        os="redhat"
        os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
        group_name="nogroup"
else
        echo "Looks like you aren't running this installer on Redhat"
        exit
fi

if [[ "$os" == "redhat" && "$os_version" -lt 79 ]]; then
        echo "Redhat 7.9 or higher is required to use this installer
This version of Redhat is too old and unsupported"
        exit
fi

# Check if user is root
if [[ "$EUID" -ne 0 ]]; then
        echo "Sorry, you need to run this as root"
        exit
fi

# Check if the required packages are installed
if  [ ! -e '/usr/bin/wget' ] || [ ! -e '/usr/bin/fio' ] || [ ! -e '/usr/bin/curl' ] || [ ! -e '/usr/bin/jq' ]; then
    echo "Error: Couldn't find [wget, curl, jq, fio, iperf3, sysbench]"
    read -p "Press enter to install the required packages "

    yum update -y && \
        yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y && \
        yum install epel-release -y && \
        yum install libpmem-devel-1.1-1.el7.x86_64 -y && \
        yum install wget curl jq fio iperf3 sysbench -y \
        yum remove epel-release -y
fi

# check for local fio/iperf/sysbench installs
command -v /usr/bin/fio >/dev/null 2>&1 && LOCAL_FIO=true || unset LOCAL_FIO
command -v /usr/bin/iperf3 >/dev/null 2>&1 && LOCAL_IPERF=true || unset LOCAL_IPERF
command -v /usr/bin/sysbench >/dev/null 2>&1 && LOCAL_SYSBENCH=true || unset LOCAL_SYSBENCH

# Test IPv6 connectivity
ipv6=$( wget -qO- -t1 -T2 ipv6.icanhazip.com )
# Get public IP for ASN/ ISP check
#
ipv4=$( wget -qO- -t1 -T2 icanhazip.com )

# test if the host has IPv4/IPv6 connectivity
IPV4_CHECK=$((ping -4 -c 1 -W 4 test-ipv4.com >/dev/null 2>&1 && echo true) || curl -s -4 -m 4 icanhazip.com 2> /dev/null)
IPV6_CHECK=$((ping -6 -c 1 -W 4 test-ipv6.com >/dev/null 2>&1 && echo true) || curl -s -6 -m 4 icanhazip.com 2> /dev/null)


# # Colors
# RED='\033[0;31m'
# GREEN='\033[0;32m'
# YELLOW='\033[0;33m'
# BLUE='\033[0;36m'
# PLAIN='\033[0m'
#

#
#
# FUNCTIONS
#
#

get_netinfo() {
    isp=$(curl -s http://ip-api.com/json/$ipv4 | jq '.isp' | sed 's/"//g')
    as=$(curl -s http://ip-api.com/json/$ipv4 | jq '.as' | sed 's/"//g')
}

get_op_sys() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
}

get_sys_type() {
    # systemd-detect-virt detects execution in a virtualized environment. https://www.freedesktop.org/software/systemd/man/systemd-detect-virt.html
    if [ $(systemd-detect-virt) == none ]; then
            sys_type="Baremetal"
        elif [ $(systemd-detect-virt) == kvm ]; then
            sys_type="KVM"
        elif [ $(systemd-detect-virt) == lxc ]; then
            sys_type="LXC"
        elif [ $(systemd-detect-virt) == openvz ]; then
            sys_type="OpenVZ"
        elif [ $(systemd-detect-virt) == xen ]; then
            sys_type="XEN"
        elif [ $(systemd-detect-virt) == microsoft ]; then
            sys_type="HYPER-V"
    fi
}

next() {
    printf "%-5s\n" "-" | sed 's/\s/-/g'
}

# speed_test() {
#     local output=$(LANG=C wget -O /dev/null -T30 $1 2>&1)
#     local speedtest=$(printf '%s' "$output" | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}')
#     local nodeName=$2
#     printf "%-32s%-24s%-14s\n" "${nodeName}" "${speedtest}"
# }

# speed_result() {
#     speed_test 'http://speedtest.frankfurt.linode.com/100MB-frankfurt.bin' 'Frankfurt, Linode'
#     speed_test 'https://fra-de-ping.vultr.com/vultr.com.100MB.bin' 'Frankfurt, Vultr'
#     speed_test 'http://fra36-speedtest-1.tele2.net/100MB.zip' 'Frankfurt, TELE2'
#     speed_test 'http://fsn.icmp.hetzner.com/100MB.bin' 'Falkenstein, Hetzner'
#     speed_test 'https://speed.hetzner.de/100MB.bin' 'Nuremberg, Hetzner'
#     speed_test 'http://hel.icmp.hetzner.com/100MB.bin' 'Helsinki, Hetzner'
#     speed_test 'http://speedtest-ams2.digitalocean.com/100mb.test' 'Amsterdam, Digitalocean'
#     speed_test 'http://speedtest.london.linode.com/100MB-london.bin' 'London, Linode'
#     speed_test 'https://par-fr-ping.vultr.com/vultr.com.100MB.bin' 'Paris, Vultr'
#     speed_test 'http://speedtest.newark.linode.com/100MB-newark.bin' 'Newark, Linode'
#     speed_test 'http://speedtest.fremont.linode.com/100MB-newark.bin' 'Fremont, Linode'
#     speed_test 'https://tx-us-ping.vultr.com/vultr.com.100MB.bin' 'Texas, Vultr'
#     speed_test 'http://speedtest.singapore.linode.com/100MB-singapore.bin' 'Singapore, Linode'
# }

ping_test() {
    local nodename=$2
    local output=$(ping -w 2 $1 | grep rtt | cut -d'/' -f4 | awk '{ print $3 }')
    local output="$output ms"
    printf "%-32s%-24s%-14s\n" "${nodename}" "${output}"
}

ping_result() {
  ping_test 'speedtest.frankfurt.linode.com' 'Frankfurt'
  ping_test 'speedtest.newark.linode.com' 'New York'
  ping_test 'speedtest.fremont.linode.com' 'San Francisco'
  ping_test 'speedtest.singapore.linode.com' 'Singapore'
  ping_test 'speedtest.tokyo2.linode.com' 'Tokyo'
}

io_test() {
  # Run rand read/write mixed 512kb fio test

  if [ -z $FIO_BENCH_MOUNTPOINT ]; then
      FIO_BENCH_MOUNTPOINT=/root
  fi

  if [ -z $FIO_SIZE ]; then
      FIO_SIZE=2G
  fi

  if [ -z $FIO_OFFSET_INCREMENT ]; then
      FIO_OFFSET_INCREMENT=500M
  fi

  if [ -z $FIO_DIRECT ]; then
      FIO_DIRECT=1
  fi

  echo "Working dir: $FIO_BENCH_MOUNTPOINT"
  echo

  if [ "$1" = 'fio' ]; then

      # READ_IOPS_VAL   =$(echo "$READ_IOPS"    |grep -E 'read ?:'  |grep -Eoi 'IOPS=[0-9k.]+'      |cut -d'=' -f2)
      # WRITE_IOPS_VAL  =$(echo "$WRITE_IOPS"   |grep -E 'write:'   |grep -Eoi 'IOPS=[0-9k.]+'      |cut -d'=' -f2)
      # READ_BW_VAL     =$(echo "$READ_BW"      |grep -E 'read ?:'  |grep -Eoi 'BW=[0-9GMKiBs/.]+'  |cut -d'=' -f2)

      echo Testing Read IOPS...

      READ_IOPS=$(fio --randrepeat=0 --verify=0 --ioengine=libaio \
      --direct=$FIO_DIRECT --gtod_reduce=1 --name=read_iops \
      --filename=$FIO_BENCH_MOUNTPOINT/fiotest --bs=4K --iodepth=64 \
      --size=$FIO_SIZE --readwrite=randread --time_based --ramp_time=2s \
      --runtime=15s  --output-format=json | jq '.jobs[].read | del(.clat_ns) | del(.lat_ns) | del(.slat_ns)' )

      # JSON OUTPUT
      echo "   \"fio.jobs.read\" : [ $READ_IOPS ] " | tee -a $RESULT_OUT
      echo " , " | tee -a $RESULT_OUT

      echo Testing Write IOPS...
      WRITE_IOPS=$(fio --randrepeat=0 --verify=0 --ioengine=libaio \
      --direct=$FIO_DIRECT --gtod_reduce=1 --name=write_iops \
      --filename=$FIO_BENCH_MOUNTPOINT/fiotest --bs=4K --iodepth=64 \
      --size=$FIO_SIZE --readwrite=randwrite --time_based --ramp_time=2s \
      --runtime=15s --output-format=json | jq '.jobs[].write | del(.clat_ns) | del(.lat_ns) | del(.slat_ns)' )

      # JSON OUTPUT
      echo "   \"fio.jobs.write\" : [ $WRITE_IOPS ] " | tee -a $RESULT_OUT
      echo " , " | tee -a $RESULT_OUT

      echo Testing Read Bandwidth...
      READ_BW=$(fio --randrepeat=0 --verify=0 --ioengine=libaio \
      --direct=$FIO_DIRECT --gtod_reduce=1 --name=read_bw \
      --filename=$FIO_BENCH_MOUNTPOINT/fiotest --bs=128K --iodepth=64 \
      --size=$FIO_SIZE --readwrite=randread --time_based --ramp_time=2s \
      --runtime=15s --output-format=json | jq '.jobs[].read | del(.clat_ns) | del(.lat_ns) | del(.slat_ns)' )

      # JSON OUTPUT
      echo "   \"fio.jobs.read_bw\" : [ $READ_BW ] " | tee -a $RESULT_OUT
      echo " , " | tee -a $RESULT_OUT

      echo Testing Write Bandwidth...
      WRITE_BW=$(fio --randrepeat=0 --verify=0 --ioengine=libaio \
      --direct=$FIO_DIRECT --gtod_reduce=1 --name=write_bw \
      --filename=$FIO_BENCH_MOUNTPOINT/fiotest --bs=128K --iodepth=64 \
      --size=$FIO_SIZE --readwrite=randwrite --time_based --ramp_time=2s \
      --runtime=15s --output-format=json | jq '.jobs[].write | del(.clat_ns) | del(.lat_ns) | del(.slat_ns)' )

      # JSON OUTPUT
      echo "   \"fio.jobs.write_bw\" : [ $WRITE_BW ] " | tee -a $RESULT_OUT
      echo " , " | tee -a $RESULT_OUT

      if [ "$FIO_BENCH_QUICK" == "" ] || [ "$FIO_BENCH_QUICK" == "no" ]; then
          # READ_LATENCY_VAL    =$(echo "$READ_LATENCY" |grep ' lat.*avg'   |grep -Eoi 'avg=[0-9.]+'                |cut -d'=' -f2)
          # WRITE_LATENCY_VAL   =$(echo "$WRITE_LATENCY"|grep ' lat.*avg'   |grep -Eoi 'avg=[0-9.]+'                |cut -d'=' -f2)
          # READ_SEQ_VAL        =$(echo "$READ_SEQ"     |grep -E 'READ:'    |grep -Eoi '(aggrb|bw)=[0-9GMKiBs/.]+'  |cut -d'=' -f2)
          # WRITE_SEQ_VAL       =$(echo "$WRITE_SEQ"    |grep -E 'WRITE:'   |grep -Eoi '(aggrb|bw)=[0-9GMKiBs/.]+'  |cut -d'=' -f2)

          echo Testing Read Latency...
          READ_LATENCY=$(fio --randrepeat=0 --verify=0 --ioengine=libaio \
          --direct=$FIO_DIRECT --name=read_latency \
          --filename=$FIO_BENCH_MOUNTPOINT/fiotest --bs=4K --iodepth=4 \
          --size=$FIO_SIZE --readwrite=randread --time_based --ramp_time=2s \
          --runtime=15s --output-format=json | jq '.jobs[].read.lat_ns' )

          # JSON OUTPUT
          echo "   \"fio.jobs.read.lat_ns\" : [ $READ_LATENCY " | tee -a $RESULT_OUT
          echo " ] , " | tee -a $RESULT_OUT

          echo Testing Write Latency...
          WRITE_LATENCY=$(fio --randrepeat=0 --verify=0 --ioengine=libaio \
          --direct=$FIO_DIRECT --name=write_latency \
          --filename=$FIO_BENCH_MOUNTPOINT/fiotest --bs=4K --iodepth=4 \
          --size=$FIO_SIZE --readwrite=randwrite --time_based --ramp_time=2s \
          --runtime=15s --output-format=json | jq '.jobs[].write.lat_ns' )

          # JSON OUTPUT
          echo "   \"fio.jobs.write.lat_ns\" : [ $WRITE_LATENCY " | tee -a $RESULT_OUT
          echo " ] , " | tee -a $RESULT_OUT

          echo Testing Read Sequential Speed...
          READ_SEQ=$(fio --randrepeat=0 --verify=0 --ioengine=libaio \
          --direct=$FIO_DIRECT --gtod_reduce=1 --name=read_seq \
          --filename=$FIO_BENCH_MOUNTPOINT/fiotest --bs=1M --iodepth=16 \
          --size=$FIO_SIZE --readwrite=read --time_based --ramp_time=2s \
          --runtime=15s --thread --numjobs=4 --offset_increment=$FIO_OFFSET_INCREMENT )
          READ_SEQ_VAL=$(echo "$READ_SEQ"|grep -E 'READ:'|grep -Eoi '(aggrb|bw)=[0-9GMKiBs/.]+'|cut -d'=' -f2)

          # JSON OUTPUT
          echo "   \"fio.jobs.read_seq\" : \"$READ_SEQ_VAL\" , " | tee -a $RESULT_OUT

          echo Testing Write Sequential Speed...
          WRITE_SEQ=$(fio --randrepeat=0 --verify=0 --ioengine=libaio \
          --direct=$FIO_DIRECT --gtod_reduce=1 --name=write_seq \
          --filename=$FIO_BENCH_MOUNTPOINT/fiotest --bs=1M --iodepth=16 \
          --size=$FIO_SIZE --readwrite=write --time_based --ramp_time=2s \
          --runtime=15s --thread --numjobs=4 --offset_increment=$FIO_OFFSET_INCREMENT )
          WRITE_SEQ_VAL=$(echo "$WRITE_SEQ"|grep -E 'WRITE:'|grep -Eoi '(aggrb|bw)=[0-9GMKiBs/.]+'|cut -d'=' -f2)

          # JSON OUTPUT
          echo "   \"fio.jobs.write_seq\" : \"$WRITE_SEQ_VAL\" , " | tee -a $RESULT_OUT

          echo Testing Read/Write Mixed...
          RW_MIX=$(fio --randrepeat=0 --verify=0 --ioengine=libaio \
          --direct=$FIO_DIRECT --gtod_reduce=1 --name=rw_mix \
          --filename=$FIO_BENCH_MOUNTPOINT/fiotest --bs=4k --iodepth=64 \
          --size=$FIO_SIZE --readwrite=randrw --rwmixread=75 \
          --time_based --ramp_time=2s --runtime=15s )
          RW_MIX_R_IOPS=$(echo "$RW_MIX"|grep -E 'read ?:'|grep -Eoi 'IOPS=[0-9k.]+'|cut -d'=' -f2)
          RW_MIX_W_IOPS=$(echo "$RW_MIX"|grep -E 'write:'|grep -Eoi 'IOPS=[0-9k.]+'|cut -d'=' -f2)

          # JSON OUTPUT
          echo " \"iops.rw_mix\": [ " | tee -a $RESULT_OUT
          echo "       { " | tee -a $RESULT_OUT
          echo "          \"fio.jobs.rw_mix_r_iops\" : \"$RW_MIX_R_IOPS\" , " | tee -a $RESULT_OUT
          echo "          \"fio.jobs.rw_mix_w_iops\" : \"$RW_MIX_W_IOPS\"  " | tee -a $RESULT_OUT
          echo "       } " | tee -a $RESULT_OUT
          echo " ] , " | tee -a $RESULT_OUT

      fi

    echo All tests complete.

    if [ -z $FIO_BENCH_QUICK ] || [ "$FIO_BENCH_QUICK" == "no" ]; then
        echo
        echo ==================
        echo = Bench Summary  =
        echo ==================
        echo "Sequential Read/Write: $READ_SEQ_VAL / $WRITE_SEQ_VAL"
        echo "Mixed Random Read/Write IOPS: $RW_MIX_R_IOPS/$RW_MIX_W_IOPS"
    fi

    rm $FIO_BENCH_MOUNTPOINT/fiotest

    sleep 10
  fi
}

################
# Iperf is a tool for network performance measurement and tuning.
################
# NOTE for Service side (this will be reciprocal if we want to test the connectivity from the server )
# 1/ edit and add portnumber/tcp into /etc/services
#    $> sudo vi /etc/services
# 2/ Add port # to firewall "public" zone permanently
#    $> sudo firewall-cmd --zone=public --add-port=8010/tcp --permanent
# 3/ Reload firewall configuration
#    $> sudo firewall-cmd --reload
# 4/ Verify the new entry in iptables
#    $> sudo iptables-save | grep 8010
# 5/ Kick off the iperf server on remotehost
#    $> iperf3 -s -p 8010
# 6/ iperf3 -c remotehost -J    # Output the results in JSON format for easy parsing.

iperf_test() {

    iperf_remote_server=$1
    iperf_port=$2

    iperf_result=$( iperf3 -c $iperf_remote_server -p $iperf_port -J | jq '.end | del(.streams) | del (.cpu_utilization_percent)' )

    # JSON OUTPUT
    echo -e "   \"iperf_test\" : [ $iperf_result " | tee -a $RESULT_OUT
    echo -e " ] , " | tee -a $RESULT_OUT
}

get_sysbench_stat_value() {
    search=$1
    type=$2
    result=$(echo "$search" | grep -Po "(?<=$type:)\s+(?:[0-9]+\.[0-9]+)" | tr -d " ")
    echo $result
}

# Prime number calculation test within a given range with sysbench
cpu_sysbench() {
    # The higher is the 'number of events per second', the better is the CPU performance.
    # https://wiki.gentoo.org/wiki/Sysbench

    # CPU speed:
    #     events per second:   *.**

    # General statistics:
    #     total time:                          *.**s
    #     total number of events:              ****

    # Latency (ms):
    #          min:                                    *.**
    #          avg:                                    *.**
    #          max:                                    *.**
    #          95th percentile:                        *.**
    #          sum:                                ****.**

    # Threads fairness:
    #     events (avg/stddev):           ****.**/0.00
    #     execution time (avg/stddev):   **.**/0.00

    echo -e "   \"sysbench.cpu\" : [" | tee -a $RESULT_OUT

    for (( each=1; each<=$cores; each*=2 ));
    do
        cpu_output=$(sysbench cpu --cpu-max-prime=20000 --time=60 --threads=$each run)

        threads=$(echo "$cpu_output" | grep -Po "(?<=threads:[[:space:]])([0-9]+)" | tr -d " ")                 # threads
        time=$(echo "$cpu_output" | grep -Po "(?<=time:)\s+(?:[0-9]+\.[0-9]+)(?=s)" | tr -d " ")                # times
        events=$(echo "$cpu_output" | grep -Po "(?<=events:)\s+([0-9]+)" | tr -d " ")                           # events
        min=$( get_sysbench_stat_value "$cpu_output" "min" )                       # min
        avg=$( get_sysbench_stat_value "$cpu_output" "avg" )                       # avg
        max=$( get_sysbench_stat_value "$cpu_output" "max" )                       # max
        percentile=$( get_sysbench_stat_value "$cpu_output" "percentile" )         # percentile

        # JSON OUTPUT
        echo "                      {    \"threads\" : \"$threads\" , " | tee -a $RESULT_OUT
        echo "                           \"time\" : \"$time\" , " | tee -a $RESULT_OUT
        echo "                           \"events\" : \"$events\" , " | tee -a $RESULT_OUT
        echo "                           \"min\" : \"$min\" , " | tee -a $RESULT_OUT
        echo "                           \"avg\" : \"$avg\" , " | tee -a $RESULT_OUT
        echo "                           \"max\" : \"$max\" , " | tee -a $RESULT_OUT
        echo "                           \"percentile\" : \"$percentile\" " | tee -a $RESULT_OUT
        echo "                       } " | tee -a $RESULT_OUT

        if [[ "$cores" -ne "$each" && "$cores" -ne 1 ]]; then
           echo "  , " | tee -a $RESULT_OUT
        fi

    done

    # Closing
    echo -e " ] , " | tee -a $RESULT_OUT


    echo # Newline
}


# sysbench memory --memory-block-size=1M --memory-total-size=100G --num-threads=1 run
mem_sysbench() {
    # The higher is the 'number of transferred bits per second', the better is the Memory performance.
    # https://wiki.gentoo.org/wiki/Sysbench
    # Number of threads: *
    # **.* MiB transferred (**.* MiB/sec)
    #  total number of events:              ****
    #      min:                                    *.**
    #      avg:                                    *.**
    #      max:                                    *.**
    #      95th percentile:                        *.**

    mem_output=$(sysbench memory --memory-block-size=1M --memory-total-size=100G --num-threads=1 run)

    transferred=$(echo "$mem_output" | grep -Po "[0-9]+\.[0-9]+[[:space:]](?:GiB|MiB|TiB|KiB)\/sec")        # transferred (**.* MiB/sec)
    threads=$(echo "$mem_output" | grep -Po "(?<=threads:[[:space:]])([0-9]+)" | tr -d " ")                 # threads
    events=$(echo "$mem_output" | grep -Po "(?<=events:)\s+([0-9]+)" | tr -d " ")                           # events
    min=$( get_sysbench_stat_value "$mem_output" "min" )                       # min
    avg=$( get_sysbench_stat_value "$mem_output" "avg" )                       # avg
    max=$( get_sysbench_stat_value "$mem_output" "max" )                       # max
    percentile=$( get_sysbench_stat_value "$mem_output" "percentile" )         # percentile

    # JSON OUTPUT
    echo "   \"sysbench.memory\" : { \"transferred\" : \"$transferred\" ,   "  | tee -a $RESULT_OUT
    echo "                           \"threads\" : \"$threads\" ,   "  | tee -a $RESULT_OUT
    echo "                           \"events\" : \"$events\" ,   "  | tee -a $RESULT_OUT
    echo "                           \"min\" : \"$min\" ,   "  | tee -a $RESULT_OUT
    echo "                           \"avg\" : \"$avg\" ,   " | tee -a $RESULT_OUT
    echo "                           \"max\" : \"$max\" ,   " | tee -a $RESULT_OUT
    echo "                           \"percentile\" : \"$percentile\" " | tee -a $RESULT_OUT
    echo "                          } " | tee -a $RESULT_OUT

    echo # Newline
}

calc_disk() {
    local total_size=0
    local array=$@
    for size in ${array[@]}
    do
        [ "${size}" == "0" ] && size_t=0 || size_t=`echo ${size:0:${#size}-1}`
        [ "`echo ${size:(-1)}`" == "K" ] && size=0
        [ "`echo ${size:(-1)}`" == "M" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' / 1024}' )
        [ "`echo ${size:(-1)}`" == "T" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' * 1024}' )
        [ "`echo ${size:(-1)}`" == "G" ] && size=${size_t}
        total_size=$( awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}' )
    done
    echo ${total_size}
}

echo -e $(date)

# override locale to eliminate parsing errors (i.e. using commas as delimiters rather than periods)
export LC_ALL=C

# gather basic system information (inc. CPU, AES-NI/virt status, RAM + swap + disk size)
cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
cpu_aes=$(cat /proc/cpuinfo | grep aes)
[[ -z "$cpu_aes" ]] && cpu_aes="\xE2\x9D\x8C Disabled" || cpu_aes="\xE2\x9C\x94 Enabled"
tram=$( free -m | awk '/Mem/ {print $2}' )
uram=$( free -m | awk '/Mem/ {print $3}' )
swap=$( free -m | awk '/Swap/ {print $2}' )
uswap=$( free -m | awk '/Swap/ {print $3}' )
up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hour %d min\n",a,b,c)}' /proc/uptime )
load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
opsy=$( get_op_sys )
arch=$( uname -m )
lbit=$( getconf LONG_BIT )
kern=$( uname -r )
disk_size1=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem|udev|docker' | awk '{print $2}' ))
disk_size2=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem|udev|docker' | awk '{print $3}' ))
disk_total_size=$( calc_disk "${disk_size1[@]}" )
disk_used_size=$( calc_disk "${disk_size2[@]}" )

next
echo -e "Get Sys Perf -- HPE HYBRID CLOUD"
next
get_netinfo
get_sys_type


echo -e "{" | tee $RESULT_OUT
echo -e " \"Basic System Information\": [ " | tee -a $RESULT_OUT
echo -e "   {" | tee -a $RESULT_OUT
echo -e "         \"Date\"                 : \"$DATE\" ," | tee -a $RESULT_OUT
echo -e "         \"System type\"          : \"$sys_type\" ," | tee -a $RESULT_OUT
echo -e "         \"CPU model\"            : \"$cname\" ," | tee -a $RESULT_OUT
echo -e "         \"Number of cores\"      : \"$cores\" ," | tee -a $RESULT_OUT
echo -e "         \"CPU frequency\"        : \"$freq MHz\" ," | tee -a $RESULT_OUT
echo -e "         \"Total size of Disk\"   : \"$disk_total_size GB ($disk_used_size GB Used)\" ," | tee -a $RESULT_OUT
echo -e "         \"Total amount of Mem\"  : \"$tram MB ($uram MB Used)\" ," | tee -a $RESULT_OUT
echo -e "         \"Total amount of Swap\" : \"$swap MB ($uswap MB Used)\" ," | tee -a $RESULT_OUT
echo -e "         \"System uptime\"        : \"$up\" ," | tee -a $RESULT_OUT
echo -e "         \"Load average\"         : \"$load\" ," | tee -a $RESULT_OUT
echo -e "         \"OS\"                   : \"$opsy\" ," | tee -a $RESULT_OUT
echo -e "         \"Arch\"                 : \"$arch ($lbit Bit)\" ," | tee -a $RESULT_OUT
echo -e "         \"Kernel\"               : \"$kern\" ," | tee -a $RESULT_OUT
echo -e "         \"ISP\"                  : \"$isp\" ," | tee -a $RESULT_OUT
echo -e "         \"ASN\"                  : \"$as\" ," | tee -a $RESULT_OUT
echo -e "         \"AES-NI\"               : \"$cpu_aes\" ," | tee -a $RESULT_OUT

if [[ "$ipv6" != "" ]]; then
    echo -e "         \"IPv6 Support\"       : \"Yes\" } " | tee -a $RESULT_OUT
else
    echo -e "         \"IPv6 Support\"       : \"No\" } " | tee -a $RESULT_OUT

fi
echo -e " ] , " | tee -a $RESULT_OUT


# create a directory in the same location that the script is being run to temporarily store Benchmarking-related files

parentdir="$( dirname "$FIO_BENCH_MOUNTPOINT" )"

touch $parentdir/$DATE.test 2> /dev/null
# test if the user has write permissions in the current directory and exit if not
if [ ! -f "$parentdir/$DATE.test" ]; then
        echo -e
        echo -e "You do not have write permission in this directory. Switch to an owned directory and re-run the script.\nExiting..."
        exit 1
fi
rm $parentdir/$DATE.test


if [ ! -d "$FIO_BENCH_MOUNTPOINT" ]
then
  mkdir -p $FIO_BENCH_MOUNTPOINT
fi

# trap CTRL+C signals to exit script cleanly
trap catch_abort INT

# catch_abort
# Purpose: This method will catch CTRL+C signals in order to exit the script cleanly and remove
#          script-related files.
function catch_abort() {
        echo -e "\n** Aborting Benchmarking. Cleaning up temp files...\n"
        rm -rf $FIO_BENCH_MOUNTPOINT
        unset LC_ALL
        exit 0
}

next
echo -e "I/O Benchmarking with FIO"
next

io1=$( io_test "fio" )
echo -e "I/O bandwith(1st run)   : $io1"
# io2=$( io_test "fio" )
# echo -e "I/O bandwith(2nd run)   : $io2"
# io3=$( io_test "fio" )
# echo -e "I/O bandwith(3rd run)   : $io3"
# rawio1=$( echo $io1 | sed 's/MB//g' | sed 's/s//g' | sed 's/.$//')
# rawio2=$( echo $io2 | sed 's/MB//g' | sed 's/s//g' | sed 's/.$//')
# rawio3=$( echo $io3 | sed 's/MB//g' | sed 's/s//g' | sed 's/.$//')
# ioall=$( awk 'BEGIN{print '$rawio1' + '$rawio2' + '$rawio3'}' )
# ioavg=$( awk 'BEGIN{printf "%.1f", '$ioall' / 3}' )
# echo -e "Average I/O bandwith    : $ioavg MB/s"
next

echo -e " Network Performance Test"
next

if [ -z $IPERF_REMOTE_SERVER ]; then
    IPERF_REMOTE_SERVER=10.0.0.5
fi

if [ -z $IPERF_PORT ]; then
    IPERF_PORT=8010
fi

if [[ "$RUN_IPERF" == "Y" || "$RUN_IPERF" == "Yes" || "$RUN_IPERF" == "1" || "$RUN_IPERF" == "True" ]]; then
    iperf_test "$IPERF_REMOTE_SERVER" "$IPERF_PORT"
fi

echo -e "PING RESULTS"
printf "%-32s%-24s%-14s\n" "Location" "Latency"
ping_result
next

# We need between the server servers
#echo -e "SPEED RESULTS with WGET"
#printf "%-32s%-24s%-14s\n" "Location" "Speed"
# Speed test is not required for Vocalink project
# speed_result && next
#next

# SYSBENCH Benchmarking
# - cpu: a simple CPU benchmark
# - fileio: a filesystem-level benchmark
# - memory: a memory access benchmark
# - threads: a thread-based scheduler benchmark
# - mutex: a POSIX mutex benchmark

echo -e "CPU RESULTS with SYSBENCH"
cpu_sysbench
next

echo -e "MEMORY RESULTS with SYSBENCH"
mem_sysbench
next
echo -e "} " | tee -a $RESULT_OUT
