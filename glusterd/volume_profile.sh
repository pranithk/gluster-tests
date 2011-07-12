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

sudo /usr/local/sbin/gluster volume profile
assert_failure $?

sudo /usr/local/sbin/gluster volume create vol $host1:/tmp/1 $host1:/tmp/2

sudo gluster volume profile vol stop
assert_failure $?

sudo /usr/local/sbin/gluster volume profile vol start
assert_success $?
sudo /usr/local/sbin/gluster volume info vol | grep diagnostics.latency-measurement | grep on
assert_success $?
sudo /usr/local/sbin/gluster volume info vol | grep diagnostics.count-fop-hits | grep on
assert_success $?
sudo gluster volume profile vol start
assert_failure $?

sudo /usr/local/sbin/gluster volume profile vol stop
assert_success $?
sudo /usr/local/sbin/gluster volume info vol | grep diagnostics.latency-measurement
assert_failure $?
sudo /usr/local/sbin/gluster volume info vol | grep diagnostics.count-fop-hits
assert_failure $?
sudo gluster volume profile vol stop
assert_failure $?

sudo /usr/local/sbin/gluster volume profile vol info
assert_failure $?
sudo /usr/local/sbin/gluster volume start vol
assert_success $?
sudo /usr/local/sbin/gluster volume profile vol info
assert_failure $?
sudo /usr/local/sbin/gluster volume profile vol start
sudo /usr/local/sbin/gluster volume info vol | grep diagnostics.latency-measurement | grep on
assert_success $?
sudo /usr/local/sbin/gluster volume profile vol info
assert_success $?

sudo gluster volume stop vol --mode=script
assert_success $?
sudo gluster volume delete vol --mode=script
assert_success $?
sudo /usr/local/sbin/gluster volume create vol $host1:/tmp/1
assert_success $?
sudo /usr/local/sbin/gluster volume start vol
assert_success $?
sudo /usr/local/sbin/gluster --mode=script volume stop vol
assert_success $?
sudo /usr/local/sbin/gluster volume start vol
assert_success $?
sudo /usr/local/sbin/gluster volume add-brick vol $host1:/tmp/2
assert_success $?
sudo /usr/local/sbin/gluster --mode=script volume remove-brick vol $host1:/tmp/2
assert_success $?

for i in `seq 1 10`; do
sudo /usr/local/sbin/gluster --mode=script volume stop vol
assert_success $?
ps aux | grep gluster
sleep 1
sudo /usr/local/sbin/gluster volume start vol
assert_success $?
ps aux | grep gluster
sleep 1
done

#profile needs to be started
sudo /usr/local/sbin/gluster --mode=script volume stop vol
sudo /usr/local/sbin/gluster volume profile vol info
assert_failure $?

#profiling needs to be enabled.
sudo /usr/local/sbin/gluster volume start vol
assert_success $?
sudo /usr/local/sbin/gluster volume profile vol info
assert_failure $?

sudo /usr/local/sbin/gluster volume set vol diagnostics.latency-measurement disable
assert_success $?
sudo /usr/local/sbin/gluster volume profile vol info
assert_failure $?
sudo gluster volume profile vol stop
assert_failure $?

sudo /usr/local/sbin/gluster volume set vol diagnostics.count-fop-hits no
assert_success $?
sudo /usr/local/sbin/gluster volume profile vol info
assert_failure $?
sudo gluster volume profile vol stop
assert_failure $?


#enable only latency, should fail
sudo /usr/local/sbin/gluster volume set vol diagnostics.latency-measurement enable
assert_success $?
sudo /usr/local/sbin/gluster volume profile vol info
assert_failure $?
sudo gluster volume profile vol stop
assert_failure $?


#enable only fd_stats, should fail
sudo /usr/local/sbin/gluster volume set vol diagnostics.latency-measurement no
assert_success $?
sudo /usr/local/sbin/gluster volume set vol diagnostics.count-fop-hits yes
assert_success $?
sudo /usr/local/sbin/gluster volume profile vol info
assert_failure $?
sudo gluster volume profile vol stop
assert_failure $?

#enable only fd_stats, should fail
sudo /usr/local/sbin/gluster volume set vol diagnostics.latency-measurement yes
assert_success $?
sudo /usr/local/sbin/gluster volume profile vol info
assert_success $?
sudo gluster volume profile vol start
assert_failure $?

sudo gluster volume profile vol stop
assert_success $?

#profile start and test the info, should succeed
sudo /usr/local/sbin/gluster volume profile vol start
assert_success $?
sudo mkdir /mnt/client
sudo mkdir /mnt/client2
sudo mkdir /mnt/client3
sudo umount /mnt/client
sudo mount -t glusterfs $host1:vol /mnt/client
assert_success $?
sudo dd if=/dev/zero of=/mnt/client/file.txt bs=1k count=1000
sudo /usr/local/sbin/gluster volume profile vol info
assert_success $?

## test cases with more than one machine, no bricks on the other machine
sudo /usr/local/sbin/gluster peer probe $host2
assert_success $?
sleep 5
sudo /usr/local/sbin/gluster volume create vol2 $host1:/tmp/2 $host1:/tmp/3
assert_success $?
sudo /usr/local/sbin/gluster volume start vol2
assert_success $?
sudo /usr/local/sbin/gluster --mode=script volume stop vol2
assert_success $?
sudo /usr/local/sbin/gluster volume start vol2
assert_success $?
sudo /usr/local/sbin/gluster volume profile vol2 start
assert_success $?
sudo umount /mnt/client2
sudo mount -t glusterfs $host1:vol2 /mnt/client2
assert_success $?
cd /mnt/client2
sudo iozone -a -g 1024
sudo dd if=/dev/zero of=/mnt/client2/file.txt bs=1k count=1000
#sudo dbench -s 1
cd -
sudo /usr/local/sbin/gluster volume profile vol2 info
assert_success $?

## test cases with more than one machine, no bricks on the originator machine
sudo /usr/local/sbin/gluster peer probe $host2
assert_success $?
sudo /usr/local/sbin/gluster volume create vol3 $host2:/tmp/2
assert_success $?
sudo /usr/local/sbin/gluster volume start vol3
assert_success $?
sudo /usr/local/sbin/gluster --mode=script volume stop vol3
assert_success $?
sudo /usr/local/sbin/gluster volume start vol3
assert_success $?
sudo /usr/local/sbin/gluster volume profile vol3 start
assert_success $?
sudo mkdir /mnt/client3
sudo umount /mnt/client3
sudo mount -t glusterfs $host1:vol3 /mnt/client3
assert_success $?
cd /mnt/client3
sudo iozone -a -g 1024
#sudo dbench -s 1
cd -
sudo /usr/local/sbin/gluster volume profile vol3 info
assert_success $?

## test cases with more than one machine, bricks on both machines
sudo /usr/local/sbin/gluster peer probe $host2
assert_success $?
sudo /usr/local/sbin/gluster volume create vol4 $host1:/tmp/4 $host2:/tmp/4
assert_success $?
sudo /usr/local/sbin/gluster volume start vol4
assert_success $?
sudo /usr/local/sbin/gluster --mode=script volume stop vol4
assert_success $?
sudo /usr/local/sbin/gluster volume start vol4
assert_success $?
sudo /usr/local/sbin/gluster volume profile vol4 start
assert_success $?
sudo umount /mnt/client2
sudo mount -t glusterfs $host1:vol4 /mnt/client2
assert_success $?
cd /mnt/client2
sudo iozone -a -g 1024
#sudo dbench -s 1
cd -
sudo /usr/local/sbin/gluster volume profile vol4 info
assert_success $?
sudo umount /mnt/client /mnt/client2 /mnt/client3
sudo /usr/local/sbin/gluster --mode=script volume stop vol
sudo /usr/local/sbin/gluster --mode=script volume stop vol2
sudo /usr/local/sbin/gluster --mode=script volume stop vol3
sudo /usr/local/sbin/gluster --mode=script volume stop vol4
sudo /usr/local/sbin/gluster --mode=script volume delete vol
sudo /usr/local/sbin/gluster --mode=script volume delete vol2
sudo /usr/local/sbin/gluster --mode=script volume delete vol3
sudo /usr/local/sbin/gluster --mode=script volume delete vol4
