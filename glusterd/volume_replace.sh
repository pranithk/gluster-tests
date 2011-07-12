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

echo "host1-cmd host1-source host1-dst"
sudo gluster volume create vol $host1:/tmp/1
assert_success $?
sudo gluster volume start vol
assert_success $?
sudo gluster volume replace-brick vol $host1:/tmp/1 $host1:/tmp/2 start
assert_success $?
sleep 5
sudo gluster volume replace-brick vol $host1:/tmp/1 $host1:/tmp/2 commit
assert_success $?
sleep 5
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

echo "host1-cmd host1-source host2-dst"
sudo gluster volume create vol $host1:/tmp/1
assert_success $?
sudo gluster volume start vol
assert_success $?
sudo gluster volume replace-brick vol $host1:/tmp/1 $host2:/tmp/2 start
assert_success $?
sleep 5
sudo gluster volume replace-brick vol $host1:/tmp/1 $host2:/tmp/2 commit
assert_success $?
sleep 5
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

echo "host1-cmd host2-source host1-dst"
sudo gluster volume create vol $host2:/tmp/1
assert_success $?
sudo gluster volume start vol
assert_success $?
sudo gluster volume replace-brick vol $host2:/tmp/1 $host1:/tmp/2 start
assert_success $?
sleep 5
sudo gluster volume replace-brick vol $host2:/tmp/1 $host1:/tmp/2 commit
assert_success $?
sleep 5
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

echo "host1-cmd host2-source host2-dst"
sudo gluster volume create vol $host2:/tmp/1
assert_success $?
sudo gluster volume start vol
assert_success $?
sudo gluster volume replace-brick vol $host2:/tmp/1 $host2:/tmp/2 start
assert_success $?
sleep 5
sudo gluster volume replace-brick vol $host2:/tmp/1 $host2:/tmp/2 commit
assert_success $?
sleep 5
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

echo "host2-cmd host1-source host1-dst"
sudo gluster volume create vol $host1:/tmp/1
assert_success $?
sudo gluster volume start vol
assert_success $?
ssh root@$host2 gluster volume replace-brick vol $host1:/tmp/1 $host1:/tmp/2 start
assert_success $?
sleep 5
ssh root@$host2 gluster volume replace-brick vol $host1:/tmp/1 $host1:/tmp/2 commit
assert_success $?
sleep 5
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

echo "host2-cmd host1-source host2-dst"
sudo gluster volume create vol $host1:/tmp/1
assert_success $?
sudo gluster volume start vol
assert_success $?
ssh root@$host2 gluster volume replace-brick vol $host1:/tmp/1 $host2:/tmp/2 start
assert_success $?
sleep 5
ssh root@$host2 gluster volume replace-brick vol $host1:/tmp/1 $host2:/tmp/2 commit
assert_success $?
sleep 5
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

echo "host2-cmd host2-source host1-dst"
sudo gluster volume create vol $host2:/tmp/1
assert_success $?
sudo gluster volume start vol
assert_success $?
ssh root@$host2 gluster volume replace-brick vol $host2:/tmp/1 $host1:/tmp/2 start
assert_success $?
sleep 5
ssh root@$host2 gluster volume replace-brick vol $host2:/tmp/1 $host1:/tmp/2 commit
assert_success $?
sleep 5
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

echo "host2-cmd host2-source host2-dst"
sudo gluster volume create vol $host2:/tmp/1
assert_success $?
sudo gluster volume start vol
assert_success $?
ssh root@$host2 gluster volume replace-brick vol $host2:/tmp/1 $host2:/tmp/2 start
assert_success $?
sleep 5
ssh root@$host2 gluster volume replace-brick vol $host2:/tmp/1 $host2:/tmp/2 commit
assert_success $?
sleep 5
sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?
