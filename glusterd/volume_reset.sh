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
sudo gluster volume create vol $host1:/tmp/1
assert_success $?
sudo gluster volume reset vol
assert_success $?
gluster volume set vol nfs.volume-access read-write
assert_success $?
gluster volume set vol nfs.trusted-write on
assert_success $?
gluster volume set vol nfs.trusted-sync on
assert_success $?
gluster volume set vol nfs.export-dirs on
assert_success $?
gluster volume set vol nfs.export-volumes on
assert_success $?
gluster volume set vol nfs.rpc-auth-allow myhost
assert_success $?
gluster volume set vol nfs.rpc-auth-reject myhost
assert_success $?
gluster volume set vol nfs.addr-namelookup on
assert_success $?
gluster volume set vol nfs.enable-ino32 on
assert_success $?
gluster volume set vol nfs.register-with-portmap off
assert_success $?
gluster volume set vol nfs.port 2445
assert_success $?
sudo gluster volume reset vol
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?
