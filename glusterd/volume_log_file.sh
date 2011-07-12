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
sudo gluster volume log filename vol /tmp/logs
assert_failure $?

#2 should err on non-existing brick
echo 2
sudo gluster volume create vol $host1:/tmp/1
assert_success $?
sudo gluster volume log filename vol abcd:/tmp/def /tmp/def
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

#3 should error when the path is a file
echo 3
sudo gluster volume create vol $host1:/tmp/1 $host2:/tmp/2
assert_success $?
sudo gluster volume log filename vol /etc/passwd
assert_failure $?
sudo gluster volume log filename vol /tmp/hijk/asb
assert_failure $?
sudo gluster volume delete vol --mode=script
assert_success $?

#4 succeed on existing volume
echo 4
sudo gluster volume create vol $host1:/tmp/1 $host2:/tmp/2
assert_success $?
sudo gluster volume log filename vol $ip1:/tmp/1 /tmp/abcd
assert_success $?
sudo gluster volume log filename vol $ip2:/tmp/2 /tmp/defg
assert_success $?
sudo gluster volume log locate vol
assert_success $?
sudo gluster volume log locate vol $ip1:/tmp/1
assert_success $?
sudo gluster volume log locate vol $ip2:/tmp/2
assert_success $?
sudo gluster volume log filename vol /tmp/hijk
assert_success $?
sudo gluster volume log locate vol
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?
