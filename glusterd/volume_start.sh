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

sudo gluster peer probe $host1
sudo gluster peer probe $host2
sleep 3

#1 Error on non existing volume start
echo 1
sudo gluster volume start vol
assert_failure $?
sudo gluster volume start vol force
assert_failure $?

#2 successfully start volume
echo 2
sudo gluster volume create vol $host1:/tmp/1 $host2:/tmp/2 $ip2:/tmp/3 $ip1:/tmp/4
assert_success $?
sudo gluster volume start vol
assert_success $?
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

#3 fail starting already started volume
echo 3
sudo gluster volume create vol $host1:/tmp/1 $host2:/tmp/2 $ip2:/tmp/3 $ip1:/tmp/4
assert_success $?
sudo gluster volume start vol
assert_success $?
sudo gluster volume start vol
assert_failure $?
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

#4 successfully starting already started volume
echo 4
sudo gluster volume create vol $host1:/tmp/1 $host2:/tmp/2 $ip2:/tmp/3 $ip1:/tmp/4
assert_success $?
sudo gluster volume start vol
assert_success $?
sudo gluster volume start vol force
assert_success $?
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

