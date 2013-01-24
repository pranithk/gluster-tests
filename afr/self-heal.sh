#!/bin/bash
if [ -z $1]; then
        echo "Usage: $0 <username>"
        exit 1
fi

T=0
DESC=""
HOSTNAME=`hostname`
USER=$1
WD="/var/lib/glusterd"
FAILURES[0]=""

function assert_success {
        if [ $1 != 0 ] ; then
                FAILURES[$T]=$DESC
        fi
}

function assert_failure {
        if [ $1 == 0 ] ; then
                FAILURES[$T]=$DESC
        fi
}

function init_test_bed {
T=$(($T+1))
DESC=$1
echo "$T)$DESC"
cd ~
rm -rf /tmp/0 /tmp/1 /tmp/2 /tmp/3
umount /mnt/client
gluster volume create vol replica 4 $HOSTNAME:/tmp/0 $HOSTNAME:/tmp/1 $HOSTNAME:/tmp/2 $HOSTNAME:/tmp/3 --mode=script
assert_success $?
gluster volume set vol self-heal-daemon off
gluster volume set vol stat-prefetch off
gluster volume start vol
assert_success $?
sleep 1
gluster volume set vol cluster.background-self-heal-count 0
gluster volume set vol diagnostics.client-log-level DEBUG
assert_success $?
sleep 1
#valgrind --leak-check=yes --log-file=$WD/valgrind$1.log /usr/local/sbin/glusterfs --log-level=INFO --volfile-id=/vol --volfile-server=localhost /mnt/client --attribute-timeout=0 --entry-timeout=0
/usr/local/sbin/glusterfs --volfile-id=/vol --volfile-server=$HOSTNAME /mnt/client --attribute-timeout=0 --entry-timeout=0
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
rm -rf /tmp/{0,1,2,3}/.glusterfs
diff <($AREQUAL /tmp/0) <($AREQUAL /tmp/1)
assert_success $?
diff <($AREQUAL /tmp/0) <($AREQUAL /tmp/2)
assert_success $?
diff <($AREQUAL /tmp/0) <($AREQUAL /tmp/3)
assert_success $?
}

function print_failures {
echo "-----------SUMMARY-----------"
for i in `seq 1 $T`
do
        if [ -z "${FAILURES[$i]}" ]; then
                continue;
        fi
        echo "$i - ${FAILURES[$i]}"
done
}

init_test_bed "Test for failure when the entry does not exist"
ls abcd
assert_failure $?
reset_test_bed

init_test_bed "Test for estale when the fs is stale"
touch file
setfattr -n trusted.gfid -v 0sBfz5vAdHTEK1GZ99qjqTIg== /tmp/0/file
find /mnt/client/file | xargs stat
assert_failure $?
reset_test_bed

init_test_bed "Test should succeed for a good entry"
touch afr_success_3.txt
assert_success $?
dd if=/dev/urandom of=afr_success_3.txt bs=1M count=10
assert_success $?
ls -l afr_success_3.txt
assert_success $?
[ `ls -l afr_success_3.txt | awk '{ print $5}'` = 10485760 ]
assert_success $?
reset_test_bed


init_test_bed "Test if the source is selected based on entry transaction for directory"
mkdir -p abc/def
assert_success $?
set_read_subvolume 3
disable_self_heal
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-1.pid`
touch abc/def/ghi
gluster volume start vol force
assert_success $?
sleep 20
[ `ls abc/def/` = "ghi" ]
assert_success $?
reset_test_bed

init_test_bed "Test if the source is selected based on data transaction for reg file"
set_read_subvolume 3
disable_self_heal
dd if=/dev/urandom of=afr_success_5.txt bs=1M count=1
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-1.pid`
dd if=/dev/urandom of=afr_success_5.txt bs=1M count=10
assert_success $?
gluster volume start vol force
assert_success $?
sleep 20
[ `ls -l afr_success_5.txt | awk '{ print $5}'` = 10485760 ]
assert_success $?
reset_test_bed

init_test_bed "Test if the source is selected based on metadata transaction for linkfile"
set_read_subvolume 3
disable_self_heal
touch afr_success_6.txt
assert_success $?
ln -s afr_success_6.txt link_to_afr_success_6.txt
ls -l
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-1.pid`
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

init_test_bed "Self-heal: Enoent + Success"
mkdir -p abc/def abc/ghi
dd if=/dev/urandom of=abc/file_abc.txt bs=1M count=2
dd if=/dev/urandom of=abc/def/file_abc_def_1.txt bs=1M count=2
dd if=/dev/urandom of=abc/def/file_abc_def_2.txt bs=1M count=3
dd if=/dev/urandom of=abc/ghi/file_abc_ghi.txt bs=1M count=4
assert_success $?

kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
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

#init_test_bed "Self-heal: Success + reg-file Split brain"
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

init_test_bed "Self-heal: Success + File type differs"
touch file
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
rm -f file
mkdir file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
assert_are_equal
ls -l /mnt/client
reset_test_bed

init_test_bed "Self-heal: Success + permissions differ"
touch file
chmod 666 file
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
chmod 777 file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

init_test_bed "Self-heal: Success + ownership differs"
touch file
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
chown $USER:$USER file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

echo "9.d) Self-heal: Success + size differs"
init_test_bed "file size test"
touch file
echo "write1" > file
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
echo "write2" >> file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
ls -lR /mnt/client
ls -lR /tmp/{0,1,2,3}/
echo "decrease file size test"
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
truncate -s 0 file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

init_test_bed "Self-heal: Success + gfid differs"
touch file
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
rm -f file
touch file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/file
assert_are_equal
reset_test_bed

init_test_bed "Self-heal: xattr data pending"
touch file
echo "write1" > file
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
echo "write2" > file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

init_test_bed "Self-heal: xattr metadata pending"
touch file
chown $USER:$USER file
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
chown root:root file
chown $USER:$USER file
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/file
assert_are_equal
reset_test_bed

init_test_bed "Self-heal: xattr entry pending"
mkdir -p abc/def
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
mkdir abc/ghi
mkdir abc/jkl
gluster volume start vol force
sleep 20
find /mnt/client | xargs stat
ls -l /tmp/{0,1,2,3}/abc
assert_are_equal
reset_test_bed

init_test_bed "mark source with the lowest uuid"
touch abc
chown $USER:$USER abc
chown root:root /tmp/1/abc
ls -l abc
ls -l /tmp/{0,1,2,3}/abc
reset_test_bed

init_test_bed "mark source with the lowest uuid on multiple nodes"
touch abc
chown $USER:$USER abc
chown root:root /tmp/1/abc
chown root:root /tmp/3/abc
find /mnt/client | xargs stat
ls -l /tmp/{0,1,2,3}/abc
assert_are_equal
reset_test_bed

init_test_bed "Make all the replicas fools, it should pick biggest of fools as source"
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

init_test_bed "If files dont have gfid, readdir should show them , find should fail with EIO because gfid assigning while some children are down is not accepted"
touch /tmp/0/{1..10}
assert_success $?
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
sleep 2
[ `ls | wc -l` = 10 ]
assert_success $?
find | xargs stat
assert_failure $?
reset_test_bed

init_test_bed "If Directories have xattrs with split-brain, impunge should happen for individual files"
mkdir abc
cd abc
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
touch a
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
touch b
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
touch c
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
touch d
gluster volume start vol force
sleep 20
strace touch a
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/abc
ls -l /tmp/{0,1,2,3}/abc
touch b
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/abc
ls -l /tmp/{0,1,2,3}/abc
touch c
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/abc
ls -l /tmp/{0,1,2,3}/abc
touch d
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/abc
ls -l /tmp/{0,1,2,3}/abc
assert_are_equal
reset_test_bed

#init_test_bed "If Directories have xattrs with split-brain, then impunge should happen for dir"
#assert_success $?
#kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
#sleep 1
#mkdir a
#cd a
#kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-1.pid`
#touch b
#gluster volume start vol force
#sleep 20
#kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
#touch c
#cd ../
#gluster volume start vol force
#sleep 20
#ls a
#ls -lR /tmp/{0,1,2,3}
#assert_are_equal
#reset_test_bed

init_test_bed "If Directories have xattrs with split-brain and mismatching files then impunge should not happen"
assert_success $?
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
sleep 1
mkdir a
cd a
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-1.pid`
touch b
gluster volume start vol force
sleep 22
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
touch b
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
touch b
assert_failure $?
reset_test_bed

init_test_bed "Make all the replicas fools, it should only do impunge in entry self-heal"
mkdir abc
cd abc
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
touch a
cd /mnt/client
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
cd /mnt/client/abc
touch b
cd /mnt/client
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
cd /mnt/client/abc
touch c
cd /mnt/client
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
cd /mnt/client/abc
touch d
setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAI /tmp/1/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAE /tmp/1/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAE /tmp/1/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAI /tmp/1/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAE /tmp/3/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAI /tmp/3/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAI /tmp/3/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAE /tmp/3/abc
gluster volume start vol force
sleep 20
cd ../
stat abc
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/abc
cd abc
ls a
ls b
ls c
ls d
assert_are_equal
reset_test_bed

init_test_bed "Make all the replicas fools, it should only do impunge in missing entry self-heal"
mkdir abc
cd abc
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
touch a
cd /mnt/client
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
cd /mnt/client/abc
touch b
cd /mnt/client
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
cd /mnt/client/abc
touch c
cd /mnt/client
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid`
cd /mnt/client/abc
touch d
setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAI /tmp/1/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAE /tmp/1/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAE /tmp/1/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAI /tmp/1/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAE /tmp/3/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAI /tmp/3/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAI /tmp/3/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAE /tmp/3/abc
gluster volume start vol force
sleep 20
strace touch a
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/abc
ls -l /tmp/{0,1,2,3}/abc
touch b
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/abc
ls -l /tmp/{0,1,2,3}/abc
touch c
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/abc
ls -l /tmp/{0,1,2,3}/abc
touch d
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/abc
ls -l /tmp/{0,1,2,3}/abc
assert_are_equal
reset_test_bed

init_test_bed "Make all the replicas fools, impunge of missing entry self-heal should not happen if they are confliciting"
mkdir abc
cd abc
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
touch a
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
cd /mnt/client/abc
touch a
gluster volume start vol force
sleep 20
setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAE /tmp/0/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAI /tmp/1/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAE /tmp/1/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAE /tmp/1/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAI /tmp/1/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAE /tmp/2/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAE /tmp/3/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAI /tmp/3/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAI /tmp/3/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAE /tmp/3/abc
gluster volume start vol force
sleep 20
echo 3 > /proc/sys/vm/drop_caches
strace touch a
assert_failure $?
getfattr -d -m trusted.gfid -ehex /tmp/{0,1,2,3}/abc/a
reset_test_bed

init_test_bed "If Directories don't have pending xattrs, file should not be deleted"
assert_success $?
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
sleep 1
mkdir abc
cd abc
touch b
rm -f /tmp/1/abc/b
setfattr -x trusted.afr.vol-client-0 /tmp/0/abc
setfattr -x trusted.afr.vol-client-1 /tmp/0/abc
setfattr -x trusted.afr.vol-client-2 /tmp/0/abc
setfattr -x trusted.afr.vol-client-3 /tmp/0/abc

setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAAAAAAA /tmp/1/abc
setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAAAAAAA /tmp/1/abc
setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAAAAAAA /tmp/1/abc
setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAAAAAAA /tmp/1/abc
echo 3 > /proc/sys/vm/drop_caches
ls -l /tmp/{0,1,2,3}/abc
ls b
sleep 1
ls -l /tmp/{0,1,2,3}/abc
AREQUAL="/home/$USER/workspace/tools/areqal/arequal/arequal-checksum"
rm -rf /tmp/{0,1,2,3}/.landfill
rm -rf /tmp/{0,1,2,3}/.glusterfs/indices/xattrop
diff <($AREQUAL /tmp/0) <($AREQUAL /tmp/1)
assert_success $?
ls | grep b
assert_success $?
reset_test_bed

echo "21) Forced merge of directory test"
rm -rf /tmp/0 /tmp/1 /tmp/3 /tmp/2
mkdir /tmp/0 /tmp/1 /tmp/3 /tmp/2
touch /tmp/0/a
setfattr -n trusted.gfid -v 0s+wqm/34LQnm8Ec8tCmoHEg== /tmp/0/a
touch /tmp/1/b
setfattr -n trusted.gfid -v 0sQTi1LjUkQwOhek4Oqx+daA== /tmp/1/b
touch /tmp/2/c
setfattr -n trusted.gfid -v 0sbNLOUJKQTUGs2GJvWJ8SDQ== /tmp/2/c
touch /tmp/3/d
setfattr -n trusted.gfid -v 0svtbQZq1vSLGB5uQaSo/7ng== /tmp/3/d
gluster volume create vol replica 4 $HOSTNAME:/tmp/0 $HOSTNAME:/tmp/1 $HOSTNAME:/tmp/2 $HOSTNAME:/tmp/3 --mode=script
gluster volume start vol
gluster volume set vol client-log-level DEBUG
gluster volume set vol brick-log-level DEBUG
gluster volume set vol self-heal-daemon off
mount -t glusterfs $HOSTNAME:/vol /mnt/client
cd /mnt/client
ls
sleep 1
assert_are_equal
reset_test_bed

function self_heal_no_change_log_sink_exists {
gluster volume create vol replica 4 $HOSTNAME:/tmp/0 $HOSTNAME:/tmp/1 $HOSTNAME:/tmp/2 $HOSTNAME:/tmp/3 --mode=script
gluster volume start vol
gluster volume set vol client-log-level DEBUG
gluster volume set vol brick-log-level DEBUG
gluster volume set vol self-heal-daemon off
mount -t glusterfs $HOSTNAME:/vol /mnt/client
cd /mnt/client
ls -l a
[ `ls -l a | awk '{ print $5}'` = 1048576 ]
assert_success $?
assert_are_equal
reset_test_bed
}

echo "22) If files w.o. any xattrs has size mismatch select the one with non-zero size as source"
rm -rf /tmp/0 /tmp/1 /tmp/3 /tmp/2
mkdir /tmp/0 /tmp/1 /tmp/3 /tmp/2
touch /tmp/0/a /tmp/1/a /tmp/2/a /tmp/3/a
dd if=/dev/zero of=/tmp/3/a bs=1M count=1
self_heal_no_change_log_sink_exists

echo "23) If files w.o. changelog has size mismatch select the one with non-zero size as source"
rm -rf /tmp/0 /tmp/1 /tmp/3 /tmp/2
mkdir /tmp/0 /tmp/1 /tmp/3 /tmp/2
touch /tmp/0/a /tmp/1/a /tmp/2/a /tmp/3/a
setfattr -n trusted.gfid -v 0s+wqm/34LQnm8Ec8tCmoHEg== /tmp/0/a /tmp/1/a /tmp/2/a /tmp/3/a
dd if=/dev/zero of=/tmp/3/a bs=1M count=1
self_heal_no_change_log_sink_exists

function self_heal_no_change_log_source_doesnt_exist {
gluster volume create vol replica 4 $HOSTNAME:/tmp/0 $HOSTNAME:/tmp/1 $HOSTNAME:/tmp/2 $HOSTNAME:/tmp/3 --mode=script
gluster volume set vol cluster.background-self-heal-count 0
gluster volume start vol
gluster volume set vol client-log-level DEBUG
gluster volume set vol brick-log-level DEBUG
gluster volume set vol self-heal-daemon off
mount -t glusterfs $HOSTNAME:/vol /mnt/client
cd /mnt/client
ls -l a
assert_success $?
truncate -s 0 a
assert_failure $?
}

echo "24) If files w.o. changelog has size mismatch and more than one file has non-zero size then open should fail, lookup should succeed"
rm -rf /tmp/0 /tmp/1 /tmp/3 /tmp/2
mkdir /tmp/0 /tmp/1 /tmp/3 /tmp/2
touch /tmp/0/a /tmp/1/a /tmp/2/a /tmp/3/a
setfattr -n trusted.gfid -v 0s+wqm/34LQnm8Ec8tCmoHEg== /tmp/0/a /tmp/1/a /tmp/2/a /tmp/3/a
dd if=/dev/zero of=/tmp/3/a bs=1M count=1
dd if=/dev/zero of=/tmp/2/a bs=1M count=2
self_heal_no_change_log_source_doesnt_exist
rm -f /tmp/2/a
find . | xargs stat
assert_are_equal
reset_test_bed

echo "25) If files w.o. xattrs has size mismatch and more than one file has non-zero size then open should fail, lookup should succeed"
rm -rf /tmp/0 /tmp/1 /tmp/3 /tmp/2
mkdir /tmp/0 /tmp/1 /tmp/3 /tmp/2
touch /tmp/0/a /tmp/1/a /tmp/2/a /tmp/3/a
dd if=/dev/zero of=/tmp/3/a bs=1M count=1
dd if=/dev/zero of=/tmp/2/a bs=1M count=2
self_heal_no_change_log_source_doesnt_exist
rm -f /tmp/2/a
find . | xargs stat
assert_are_equal
reset_test_bed

echo "26) If files w.o. xattrs has metadata data self-heal, self-heal should not hang"
rm -rf /tmp/0 /tmp/1 /tmp/3 /tmp/2
mkdir /tmp/0 /tmp/1 /tmp/3 /tmp/2
touch /tmp/0/a /tmp/1/a /tmp/2/a /tmp/3/a
setfattr -n trusted.gfid -v 0s+wqm/34LQnm8Ec8tCmoHEg== /tmp/0/a /tmp/1/a
dd if=/dev/zero of=/tmp/0/a bs=1M count=1
dd if=/dev/zero of=/tmp/1/a bs=1M count=2
chown $USER:$USER /tmp/1/a
gluster volume create vol replica 4 $HOSTNAME:/tmp/0 $HOSTNAME:/tmp/1 $HOSTNAME:/tmp/2 $HOSTNAME:/tmp/3 --mode=script
gluster volume start vol
gluster volume set vol client-log-level DEBUG
gluster volume set vol brick-log-level DEBUG
gluster volume set vol self-heal-daemon off
gluster volume set vol cluster.background-self-heal-count 0
#un comment this for release >= 3.3
#kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
mount -t glusterfs $HOSTNAME:/vol /mnt/client
cd /mnt/client
echo "attach to gdb"
sleep 15
ls -l a
assert_success $?
cat a
assert_failure $?
rm -f /tmp/0/a
find . | xargs stat
reset_test_bed

init_test_bed "Full self-heal of file with holes"
gluster volume set vol data-self-heal-algorithm full
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
truncate -s 1M 1
gluster volume start vol force
sleep 20
find . | xargs stat
[ `ls -ls /tmp/0/1 | awk '{print $1}'` = `ls -ls /tmp/1/1 | awk '{print $1}'` ]
assert_success $?
[ `ls -ls /tmp/0/1 | awk '{print $1}'` = `ls -ls /tmp/2/1 | awk '{print $1}'` ]
assert_success $?
[ `ls -ls /tmp/1/1 | awk '{print $1}'` = `ls -ls /tmp/3/1 | awk '{print $1}'` ]
assert_success $?
assert_are_equal
reset_test_bed

init_test_bed "Full self-heal of file with holes, file smaller than page size (128K)"
gluster volume set vol data-self-heal-algorithm full
dd if=/dev/urandom of=1 count=1 bs=1M
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
dd if=/dev/zero of=1 count=1 bs=1M
truncate -s 64k 1
gluster volume start vol force
sleep 20
find . | xargs stat
[ `ls -ls /tmp/0/1 | awk '{print $1}'` = `ls -ls /tmp/2/1 | awk '{print $1}'` ]
assert_success $?
[ `ls -ls /tmp/1/1 | awk '{print $1}'` = `ls -ls /tmp/3/1 | awk '{print $1}'` ]
assert_success $?
assert_are_equal
reset_test_bed

init_test_bed "Diff self-heal of file with holes"
gluster volume set vol data-self-heal-algorithm diff
dd if=/dev/urandom of=1 count=1 bs=1M
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
truncate -s 0 1
truncate -s 1M 1
gluster volume start vol force
sleep 20
find . | xargs stat
[ `ls -ls /tmp/0/1 | awk '{print $1}'` = `ls -ls /tmp/1/1 | awk '{print $1}'` ]
assert_success $?
[ `ls -ls /tmp/0/1 | awk '{print $1}'` = `ls -ls /tmp/2/1 | awk '{print $1}'` ]
assert_failure $?
[ `ls -ls /tmp/1/1 | awk '{print $1}'` = `ls -ls /tmp/3/1 | awk '{print $1}'` ]
assert_failure $?
assert_are_equal
reset_test_bed

init_test_bed "Full self-heal of file with holes"
gluster volume set vol data-self-heal-algorithm full
dd if=/dev/urandom of=1 count=1 bs=1M
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
truncate -s 2M 1
gluster volume start vol force
sleep 20
find . | xargs stat
[ `ls -ls /tmp/0/1 | awk '{print $1}'` = `ls -ls /tmp/1/1 | awk '{print $1}'` ]
assert_success $?
[ `ls -ls /tmp/0/1 | awk '{print $1}'` = `ls -ls /tmp/2/1 | awk '{print $1}'` ]
assert_success $?
[ `ls -ls /tmp/1/1 | awk '{print $1}'` = `ls -ls /tmp/3/1 | awk '{print $1}'` ]
assert_success $?
assert_are_equal
reset_test_bed

init_test_bed "Full self-heal of file with holes"
gluster volume set vol data-self-heal-algorithm full
dd if=/dev/urandom of=1 count=1 bs=2M
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
truncate -s 0 1
truncate -s 1M 1
gluster volume start vol force
sleep 20
find . | xargs stat
[ `ls -ls /tmp/0/1 | awk '{print $1}'` = `ls -ls /tmp/1/1 | awk '{print $1}'` ]
assert_success $?
[ `ls -ls /tmp/0/1 | awk '{print $1}'` != `ls -ls /tmp/2/1 | awk '{print $1}'` ]
assert_success $?
[ `ls -ls /tmp/1/1 | awk '{print $1}'` != `ls -ls /tmp/3/1 | awk '{print $1}'` ]
assert_success $?
assert_are_equal
reset_test_bed

init_test_bed "Delete the stale file test"
mkdir a
cd a
touch file
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
rm -f file
gluster volume start vol force
sleep 20
ls file
assert_failure $?
assert_are_equal
reset_test_bed

init_test_bed "data self-heal on split-brain tests"
touch a
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-1.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
echo "1" > a
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-0.pid $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
echo "2" > a
gluster volume start vol force
sleep 20
kill -9 `cat $WD/vols/vol/run/$HOSTNAME-tmp-2.pid $WD/vols/vol/run/$HOSTNAME-tmp-3.pid`
cat a
assert_failure $?
mkdir /mnt/client1
mount -t glusterfs $HOSTNAME:/vol /mnt/client1
cd /mnt/client1
cat a
assert_failure $?
rm -rf /tmp/0/.glusterfs/* /tmp/0/a
sleep 1
cat a
assert_success $?
[ `cat /tmp/0/a` = `cat /tmp/1/a` ]
assert_success $?
cd /mnt/client
[ `cat a` = "2" ]
assert_success $?
umount /mnt/client1
reset_test_bed

print_failures
