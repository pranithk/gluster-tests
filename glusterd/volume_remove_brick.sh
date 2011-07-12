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

#1 Error on non existing volume remove-brick
echo 1
sudo gluster volume remove-brick abcd $host1:/tmp/1 --mode=script
assert_failure $?

#2 Error on unknown-peer brick
echo 2
sudo gluster volume create vol $host1:/tmp/1
assert_success $?
sudo gluster volume remove-brick vol abcd:/tmp/2 --mode=script
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

#3 Error on non existing brick usage
echo 3
sudo gluster volume create vol $host1:/tmp/1 $host1:/tmp/2
assert_success $?
sudo gluster volume remove-brick vol $host1:/tmp/3 --mode=script
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

#4 Error on number of bricks is not sub volume count
echo 4
sudo gluster volume create vol replica 2 $host1:/tmp/1 $host1:/tmp/2 $host1:/tmp/3 $host1:/tmp/4
assert_success $?
sudo gluster volume remove-brick vol $host1:/tmp/3 --mode=script
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

#5 success on number of bricks is sub volume count
echo 5
sudo gluster volume create vol replica 2 $host1:/tmp/1 $host1:/tmp/2 $host1:/tmp/3 $host1:/tmp/4
assert_success $?
sudo gluster volume remove-brick vol $host1:/tmp/3 $host1:/tmp/4 --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

#6 add-brick should allow add-brick for filling pure replica
echo 8
sudo gluster volume create vol replica 4 $host1:/tmp/1 $host1:/tmp/2 $host1:/tmp/3 $host1:/tmp/4
assert_success $?
sudo gluster volume remove-brick vol $host1:/tmp/1 $host1:/tmp/2 $host1:/tmp/3 --mode=script
assert_success $?
sudo gluster volume add-brick vol $host1:/tmp/1 $host1:/tmp/2 $host1:/tmp/3
assert_success $?
sudo gluster volume remove-brick vol $host1:/tmp/1 $host1:/tmp/2 --mode=script
assert_success $?
sudo gluster volume add-brick vol $host1:/tmp/1 $host1:/tmp/2
assert_success $?
sudo gluster volume remove-brick vol $host1:/tmp/1 --mode=script
assert_success $?
sudo gluster volume add-brick vol $host1:/tmp/1
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

#9 Disallow (count % sub_volcount) !=0 for remove-brick on pure stripe distributed stripe/replica
echo 9
sudo gluster volume create vol replica 2 $host1:/tmp/1 $host1:/tmp/2 $host1:/tmp/3 $host1:/tmp/4
assert_success $?
sudo gluster volume remove-brick vol $host1:/tmp/1 --mode=script
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

sudo gluster volume create vol stripe 2 $host1:/tmp/1 $host1:/tmp/2
assert_success $?
sudo gluster volume remove-brick vol $host1:/tmp/1 --mode=script
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

sudo gluster volume create vol stripe 2 $host1:/tmp/1 $host1:/tmp/2 $host1:/tmp/3 $host1:/tmp/4
assert_success $?
sudo gluster volume add-brick vol $host1:/tmp/1
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

#10 remove bricks from different subvolumes should fail.
sudo gluster volume create vol replica 2 $host1:/tmp/1 $host1:/tmp/2 $host1:/tmp/3 $host1:/tmp/4
assert_success $?
sudo gluster volume remove-brick vol $host1:/tmp/1 $ip1:/tmp/3 --mode=script
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

