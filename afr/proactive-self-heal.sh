#!/bin/bash -x
HOSTNAME=`hostname`
USER=$1
WD="/var/lib/glusterd"

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

function assert_are_equal {
AREQUAL="/home/$USER/workspace/tools/areqal/arequal/arequal-checksum"
rm -rf /tmp/{0,1,2,3,4,5}/.landfill
rm -rf /tmp/{0,1,2,3,4,5}/.glusterfs
diff <($AREQUAL /tmp/0) <($AREQUAL /tmp/1)
assert_success $?
}

glusterd
gluster volume create vol replica 2 $HOSTNAME:/tmp/0 $HOSTNAME:/tmp/1 $HOSTNAME:/tmp/2 $HOSTNAME:/tmp/3 $HOSTNAME:/tmp/4 $HOSTNAME:/tmp/5 --mode=script
assert_success $?
gluster volume set vol cluster.background-self-heal-count 0
assert_success $?
gluster volume set vol diagnostics.client-log-level DEBUG
assert_success $?
gluster volume start vol
assert_success $?
sleep 1
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-4.pid`
/usr/local/sbin/glusterfs --volfile-id=/vol --volfile-server=$HOSTNAME /mnt/client --attribute-timeout=0 --entry-timeout=0
assert_success $?
sleep 1
mkdir /mnt/client
cd /mnt/client
while [ $? != 0 ]; do sleep 1; cd /mnt/client ;done
assert_success $?
for i in {1..10}
do
        for j in {1..10}
        do
                dd if=/dev/urandom of=$j bs=1M count=10;
        done
        mkdir a; cd a;
done

cd ~
umount /mnt/client
pending=`gluster volume heal vol info | grep "Number of entries" | awk '{ sum+=$4} END {print sum}'`
assert_success $?
[ $pending=101 ]
assert_success $?
gluster volume heal vol
assert_failure $?
gluster volume set vol self-heal-daemon off
gluster volume heal vol info
assert_failure $?
gluster volume heal vol
assert_failure $?
gluster volume start vol force
assert_success $?
sleep 1
gluster volume set vol self-heal-daemon on
assert_success $?
#this will also trigger index self-heal but it will not heal the entire brick
sleep 5
gluster volume heal vol
assert_success $?
sleep 5
#check that this heals the contents partially
remaining=`gluster volume heal vol info | grep "Number of entries" | awk '{ sum+=$4} END {print sum}'`
assert_success $?
[ $pending -gt $remaining ]
assert_success $?
gluster volume heal vol full
assert_success $?
sleep 20
#check that this heals the contents completely
final=`gluster volume heal vol info | grep "Number of entries" | awk '{ sum+=$4} END {print sum}'`
assert_success $?
[ $final=0 ]
assert_success $?
gluster --mode=script volume stop vol
assert_success $?
gluster --mode=script volume delete vol
assert_success $?
killall glusterd
rm -rf /tmp/{0..5}
