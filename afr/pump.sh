#!/bin/bash

set -x

if [ $1="" ];then
        dir="/usr/local/sbin/glusterd"
else
        dir=$1
fi

GLUSTERFSDIR=`dirname $dir`


function graceful_cleanup ()
{

$GLUSTERFSDIR/gluster volume stop hosdu --mode=script
$GLUSTERFSDIR/gluster volume delete hosdu --mode=script
killall -9 glusterd
rm -rf /tmp/brick*
rm -f /tmp/tempfile
umount /tmp/mnt
rm -rf /tmp/mnt/

}

function cleanup ()
{

pgrep gluster | xargs kill -9
rm -rf /etc/glusterd/*
rm -rf /tmp/mnt/*
umount /tmp/mnt
rm -rf /tmp/brick*

}

function assert_success {
        if [ $1 = 0 ] ; then
                echo "test passed"
        else
                echo "test failed"
                #cleanup
                exit 1
        fi
}

function assert_are_equal {
AREQUAL='/home/pranith/workspace/tools/areqal/arequal/arequal-checksum'
sudo rm -rf /tmp/brick{1,5}/.landfill
diff <($AREQUAL /tmp/brick1) <($AREQUAL /tmp/brick5)
assert_success $?
}

pgrep glusterd

if [ $? -ne 0 ];then
	$GLUSTERFSDIR/glusterd -LDEBUG
fi

$GLUSTERFSDIR/gluster volume create hosdu replica 2 $(hostname):/tmp/brick1/ $(hostname):/tmp/brick2/ $(hostname):/tmp/brick3/ $(hostname):/tmp/brick4/ 2>/dev/null 1>/dev/null;
$GLUSTERFSDIR/gluster volume set hosdu diagnostics.client-log-level TRACE
$GLUSTERFSDIR/gluster volume set hosdu diagnostics.brick-log-level TRACE
$GLUSTERFSDIR/gluster volume start hosdu 2>/dev/null 1>/dev/null;

mkdir /tmp/mnt/
mount -t glusterfs $(hostname):hosdu /tmp/mnt/
cpwd=`pwd`
cd /tmp/mnt/
for i in {1..40}
do
	for j in {1..10}
	do
		dd if=/dev/urandom of=file$j bs=128K count=10 2>/dev/null 1>/dev/null
	done
	mkdir dir$i && cd dir$i
done

cd $cpwd

umount /tmp/mnt/

ls -l /tmp/brick1
$GLUSTERFSDIR/gluster volume replace-brick hosdu $(hostname):/tmp/brick1/ $(hostname):/tmp/brick5/ start | grep "replace-brick started successfully" 2>/dev/null 1>/dev/null
if [ $? -ne 0 ];then
	echo "Failed to start the replace-brick"
	exit 1;
fi
sleep 5

temp=0;

while [ $temp -eq 0 ]
do

	$GLUSTERFSDIR/gluster volume replace-brick hosdu $(hostname):/tmp/brick1/ $(hostname):/tmp/brick5/ status >/tmp/tempfile # 2>/dev/null 1>/dev/null
	if [ $? -ne 0 ];then
		temp=2
	fi

	grep "Migration complete" /tmp/tempfile 2>/dev/null 1>/dev/null
	if [ $? -eq 0 ];then
                ls -l /tmp/brick5
                assert_are_equal
		temp=1;
	fi
done

if [ $temp -eq 1 ];then
	echo "replace-brick operation successfull. Commiting the replace-brick"
	$GLUSTERFSDIR/gluster volume replace-brick hosdu $(hostname):/tmp/brick1/ $(hostname):/tmp/brick5/ commit;
        #graceful_cleanup ;
elif [ $temp -eq 2 ];then
	echo "Something went Bananas and glusterfsd probably crashed. Please look into it"
	#cleanup ;
fi
rm -f /tmp/tempfile

