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
rm -rf /tmp/0 /tmp/1 /tmp/2 /tmp/3
umount /mnt/client
gluster volume create vol replica 4 `hostname`:/tmp/0 `hostname`:/tmp/1 `hostname`:/tmp/2 `hostname`:/tmp/3 --mode=script
assert_success $?
gluster volume set vol self-heal-daemon off
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
rm -rf /tmp/0 /tmp/1 /tmp/2 /tmp/3
}

function set_read_subvolume {
gluster volume set vol cluster.read-subvolume vol-client-$1
assert_success $?
}

function disable_self_heal {
gluster volume set vol cluster.data-self-heal off
assert_success $?
gluster volume set vol cluster.metadata-self-heal off
assert_success $?
gluster volume set vol cluster.entry-self-heal off
assert_success $?
}

function assert_are_equal {
AREQUAL="/home/$USER/workspace/tools/areqal/arequal/arequal-checksum"
rm -rf /tmp/{0,1,2,3}/.landfill
diff <($AREQUAL /tmp/0) <($AREQUAL /tmp/1)
assert_success $?
diff <($AREQUAL /tmp/0) <($AREQUAL /tmp/2)
assert_success $?
diff <($AREQUAL /tmp/0) <($AREQUAL /tmp/3)
assert_success $?
}

echo "1) Test for failure when the entry does not exist"
init_test_bed 1
ls abcd
assert_failure $?
reset_test_bed

echo "2) Test for estale when the fs is stale"
init_test_bed 2
touch file
setfattr -n trusted.gfid -v 0sBfz5vAdHTEK1GZ99qjqTIg== /tmp/0/file
find /mnt/client/file | xargs stat
assert_failure $?
reset_test_bed

echo "3) Test should succeed for a good entry"
init_test_bed 3
touch afr_success_3.txt
assert_success $?
dd if=/dev/urandom of=afr_success_3.txt bs=1M count=10
assert_success $?
ls -l afr_success_3.txt
assert_success $?
[ `ls -l afr_success_3.txt | awk '{ print $5}'` = 10485760 ]
assert_success $?
reset_test_bed


echo "4) Test if the source is selected based on entry transaction for directory"
init_test_bed 4
mkdir -p abc/def
assert_success $?
set_read_subvolume 3
disable_self_heal
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-1.pid`
touch abc/def/ghi
gluster volume start vol force
assert_success $?
sleep 20
[ `ls abc/def/` = "ghi" ]
assert_success $?
reset_test_bed

echo "5) Test if the source is selected based on data transaction for reg file"
init_test_bed 5
set_read_subvolume 3
disable_self_heal
dd if=/dev/urandom of=afr_success_5.txt bs=1M count=1
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-1.pid`
dd if=/dev/urandom of=afr_success_5.txt bs=1M count=10
assert_success $?
gluster volume start vol force
assert_success $?
sleep 20
[ `ls -l afr_success_5.txt | awk '{ print $5}'` = 10485760 ]
assert_success $?
reset_test_bed

echo "6) Test if the source is selected based on metadata transaction for linkfile"
init_test_bed 6
set_read_subvolume 3
disable_self_heal
touch afr_success_6.txt
assert_success $?
ln -s afr_success_6.txt link_to_afr_success_6.txt
ls -l
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-1.pid`
dd if=/dev/urandom of=link_to_afr_success_6.txt bs=1M count=10
assert_success $?
ls -l
chown -h $USER:$USER link_to_afr_success_6.txt
ls -l
gluster volume start vol force
assert_success $?
sleep 20
[ `ls -l link_to_afr_success_6.txt | awk '{ print $3}'` = $USER ]
assert_success $?
[ `ls -l link_to_afr_success_6.txt | awk '{ print $4}'` = $USER ]
assert_success $?
reset_test_bed

echo "7) Self-heal: Enoent + Success"
init_test_bed 7
mkdir -p abc/def abc/ghi
dd if=/dev/urandom of=abc/file_abc.txt bs=1M count=2
dd if=/dev/urandom of=abc/def/file_abc_def_1.txt bs=1M count=2
dd if=/dev/urandom of=abc/def/file_abc_def_2.txt bs=1M count=3
dd if=/dev/urandom of=abc/ghi/file_abc_ghi.txt bs=1M count=4
assert_success $?

kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
rm -rf abc/ghi
truncate -s 0 abc/def/file_abc_def_1.txt
chown  $USER:$USER abc/def/file_abc_def_2.txt
mkdir -p def/ghi jkl/mno
dd if=/dev/urandom of=def/ghi/file1.txt bs=1M count=2
dd if=/dev/urandom of=def/ghi/file2.txt bs=1M count=3
dd if=/dev/urandom of=jkl/mno/file.txt bs=1M count=4
chown  $USER:$USER def/ghi/file2.txt
gluster volume start vol force
assert_success $?
sleep 20
find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

#echo "8) Self-heal: Success + reg-file Split brain"
#init_test_bed 8
#create file
#bring one server down
#edit the file
#close
#take the online server down
#bring other server up
#edit again
#bring both up
#lookup
#reset_test_bed

echo "9.a) Self-heal: Success + File type differs"
init_test_bed 9a
touch file
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
rm -f file
mkdir file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

echo "9.b) Self-heal: Success + permissions differ"
init_test_bed 9b
touch file
chmod 666 file
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
chmod 777 file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

echo "9.c) Self-heal: Success + ownership differs"
init_test_bed 9c
touch file
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
chown $USER:$USER file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

echo "9.d) Self-heal: Success + size differs"
echo "increase file size test"
init_test_bed 9d
touch file
echo "write1" > file
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
echo "write2" >> file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
ls -lR /mnt/client
ls -lR /tmp/{0,1,2,3}/
echo "decrease file size test"
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
truncate -s 0 file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

echo "9.e) Self-heal: Success + gfid differs"
init_test_bed 9e
touch file
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
rm -f file
touch file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/file
assert_are_equal
reset_test_bed

echo "10.a) Self-heal: xattr data pending"
init_test_bed 10a
touch file
echo "write1" > file
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
echo "write2" > file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

echo "10.b) Self-heal: xattr metadata pending"
init_test_bed 10b
touch file
chown $USER:$USER file
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
chown root:root file
chown $USER:$USER file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/file
assert_are_equal
reset_test_bed

echo "10.c) Self-heal: xattr entry pending"
init_test_bed 10c
mkdir -p abc/def
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
mkdir abc/ghi
mkdir abc/jkl
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
ls -l /tmp/{0,1,2,3}/abc
assert_are_equal
reset_test_bed

echo "11a) mark source with the lowest uuid"
init_test_bed 11
touch abc
chown $USER:$USER abc
chown root:root /tmp/1/abc
ls -l abc
ls -l /tmp/{0,1,2,3}/abc
reset_test_bed

echo "11b) mark source with the lowest uuid on multiple nodes"
init_test_bed 11
touch abc
chown $USER:$USER abc
chown root:root /tmp/1/abc
chown root:root /tmp/3/abc
find /mnt/client | xargs stat
ls -l /tmp/{0,1,2,3}/abc
assert_are_equal
reset_test_bed

echo "12) Make all the replicas fools, it should pick biggest of fools as source"
init_test_bed 12
touch abc
setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAEAAAAA /tmp/0/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAEAAAAA /tmp/0/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAEAAAAA /tmp/0/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAEAAAAA /tmp/0/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAIAAAAA /tmp/1/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAEAAAAA /tmp/1/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAEAAAAA /tmp/1/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAIAAAAA /tmp/1/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAEAAAAA /tmp/2/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAEAAAAA /tmp/2/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAEAAAAA /tmp/2/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAEAAAAA /tmp/2/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAEAAAAA /tmp/3/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAIAAAAA /tmp/3/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAIAAAAA /tmp/3/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAEAAAAA /tmp/3/abc
ls -l abc
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/abc
assert_are_equal
reset_test_bed

echo "13) If files dont have gfid, readdir should show them , find should fail with EIO because gfid assigning while some children are down is not accepted"
init_test_bed 13
touch /tmp/0/{1..10}
assert_success $?
kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-1.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-3.pid`
sleep 2
[ `ls | wc -l` = 10 ]
assert_success $?
find | xargs stat
assert_failure $?
reset_test_bed
