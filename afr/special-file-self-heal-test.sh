#!/bin/bash -x

if [ -z $1]; then
        echo "Usage: $0 <username>"
        exit 1
fi
HOSTNAME=`hostname`
USER=$1
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

function init_test_bed {
cd ~
rm -rf /tmp/1 /tmp/2
umount /mnt/client
gluster volume create vol replica 2 `hostname`:/tmp/1 `hostname`:/tmp/2 --mode=script
assert_success $?
gluster volume start vol
assert_success $?
sleep 1
gluster volume set vol diagnostics.client-log-level DEBUG
assert_success $?
sleep 1
#valgrind --leak-check=yes --log-file=/etc/glusterd/valgrind$1.log /usr/local/sbin/glusterfs --log-level=INFO --volfile-id=/vol --volfile-server=localhost /mnt/client --attribute-timeout=0 --entry-timeout=0
/usr/local/sbin/glusterfs --volfile-id=/vol --volfile-server=`hostname` /mnt/client --attribute-timeout=0 --entry-timeout=0
assert_success $?
sleep 1
cd /mnt/client
while [ $? != 0 ]; do sleep 1; cd /mnt/client ;done
assert_success $?
mount | grep client
}

function reset_test_bed {
cd ~
umount /mnt/client
gluster volume stop vol --mode=script
gluster volume delete vol --mode=script
rm -rf /tmp/1 /tmp/2
}

echo "special file data-self-heal"
init_test_bed
rm fifo block char file link >& /dev/null
mkfifo fifo;
mknod block b 0 0;
mknod char c 0 0;
touch file
ln -s file link;
# set
cd /tmp/1
setfattr -n trusted.afr.test-client-0 -v 0x000000000000000000000000 fifo block char link;
setfattr -n trusted.afr.test-client-1 -v 0x000000010000000000000000 fifo block char link;

echo "Orig xattrs"
getfattr -m . -d -e hex fifo block char link;
sleep 1
(find /mnt/client | xargs stat) >& /dev/null
sleep 1
echo "Xattrs after self-heal"
getfattr -m . -d -e hex fifo block char link
reset_test_bed
