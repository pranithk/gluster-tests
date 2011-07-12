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

#should err on non-existing volume
echo 1
sudo gluster volume log rotate vol
assert_failure $?

#2 should err on non-existing brick
echo 2
sudo gluster volume create vol $host1:/tmp/1
assert_success $?
sudo gluster volume log rotate vol abcd:/tmp/def
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

#3 should error when the path is a file
echo 3
sudo gluster volume create vol $host1:/tmp/1 $host2:/tmp/2
assert_success $?
sudo gluster volume log rotate vol
assert_failure $?
sudo gluster volume log rotate vol
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

#4 should error when volume is not started
echo 4
sudo gluster volume create vol $host1:/tmp/1 $host2:/tmp/2
assert_success $?
sudo gluster volume log rotate vol
assert_failure $?
sudo gluster volume log rotate vol $host1:/tmp/1
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

#5 succeed on existing volume
echo 5
sudo gluster volume create vol $host1:/tmp/1 $host2:/tmp/2
assert_success $?
sudo gluster volume start vol
assert_success $?
sudo gluster volume log rotate vol $ip1:/tmp/1
assert_success $?
sudo gluster volume log rotate vol $ip2:/tmp/2
assert_success $?
sudo gluster volume log locate vol
assert_success $?
sudo gluster volume log locate vol $ip1:/tmp/1
assert_success $?
sudo gluster volume log locate vol $ip2:/tmp/2
assert_success $?
sudo gluster volume log rotate vol
assert_success $?
sudo gluster volume log locate vol
assert_success $?
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?
