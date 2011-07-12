#!/bin/bash
function assert_success {
        if [ $1 = 0 ] ; then
                echo "test passed"
        else
                echo "test failed"
        fi
}

function assert_failure {
        if [ $1 != 0 ] ; then
                echo "test passed"
        else
                echo "test failed"
        fi
}

host1=$1
host2=$2
ip1=$3
ip2=$4

sudo gluster --mode=script peer probe $host1
sudo gluster peer probe $host2
sleep 3

#1 Error on non existing volume stop
echo 1
sudo gluster --mode=script volume stop vol
assert_failure $?
sudo gluster --mode=script volume stop vol force
assert_failure $?

#2 Error on stopping already stopped volume
echo 2
sudo gluster --mode=script volume create vol $host1:/tmp/1 $host2:/tmp/2 $ip2:/tmp/3 $ip1:/tmp/4
assert_success $?
sudo gluster --mode=script volume start vol
assert_success $?
sudo gluster --mode=script volume stop vol --mode=script
assert_success $?
sudo gluster --mode=script volume stop vol --mode=script
assert_failure $?
sudo gluster --mode=script volume delete vol --mode=script
assert_success $?

#3 Error on stopping already stopped volume
echo 3
sudo gluster --mode=script volume create vol $host1:/tmp/1 $host2:/tmp/2 $ip2:/tmp/3 $ip1:/tmp/4
assert_success $?
sudo gluster --mode=script volume start vol
assert_success $?
sudo gluster --mode=script volume stop vol --mode=script
assert_success $?
sudo gluster --mode=script volume stop vol force --mode=script
assert_success $?
sudo gluster --mode=script volume delete vol --mode=script
assert_success $?

