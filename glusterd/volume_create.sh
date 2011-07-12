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

#1 Error on existing volume create
echo 1
sudo gluster volume create vol $host1:/tmp/1
assert_success $?
sudo gluster volume create vol $host1:/tmp/2
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

#2 Error on existing brick usage
echo 2
sudo gluster volume create vol $host1:/tmp/1 $host1:/tmp/2 $host1:/tmp/3 $host1:/tmp/4
assert_success $?
sudo gluster volume create vol2 $host1:/tmp/1
assert_failure $?
sudo gluster volume create vol3 $ip1:/tmp/4
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?
sudo gluster volume create vol4 $host1:/tmp/5 $host2:/tmp/6  $ip2:/tmp/6 $ip1:/tmp/5
assert_failure $?

#3 Error on using unknown peer's brick
echo 3
sudo gluster volume create vol $host1:/tmp/1 $host1:/tmp/2 $host2:/tmp/3 $host2:/tmp/4
assert_success $?
sudo gluster volume create vol2 abcd:/tmp/1
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

#4 SUCCESS on using ip,hostname inter-changeably
echo 4
sudo gluster volume create vol $host1:/tmp/1 $ip1:/tmp/2 $host2:/tmp/3 $ip2:/tmp/4
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?

#5 Error on create vol with brick as path to file
echo 5
sudo gluster volume create vol $host1:/etc/passwd
assert_failure $?

#6 create vol with brick as path to file
echo 6
sudo gluster volume create vol $host1:/tmp/abcd/def
assert_failure $?
