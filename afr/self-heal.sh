#!/bin/bash -x
HOSTNAME=`hostname`
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
sudo rm -rf /tmp/0 /tmp/1 /tmp/2 /tmp/3
sudo umount /mnt/client
sudo gluster volume create vol replica 4 `hostname`:/tmp/0 `hostname`:/tmp/1 `hostname`:/tmp/2 `hostname`:/tmp/3 --mode=script
assert_success $?
sudo gluster volume set vol self-heal-daemon off
sudo gluster volume start vol
assert_success $?
sleep 1
sudo gluster volume set vol diagnostics.client-log-level DEBUG
assert_success $?
sleep 1
#sudo valgrind --leak-check=yes --log-file=/etc/glusterd/valgrind$1.log /usr/local/sbin/glusterfs --log-level=INFO --volfile-id=/vol --volfile-server=localhost /mnt/client --attribute-timeout=0 --entry-timeout=0
sudo /usr/local/sbin/glusterfs --volfile-id=/vol --volfile-server=localhost /mnt/client --attribute-timeout=0 --entry-timeout=0
assert_success $?
sleep 1
cd /mnt/client
while [ $? != 0 ]; do sleep 1; cd /mnt/client ;done
assert_success $?
mount | grep client
}

function reset_test_bed {
cd ~
sudo umount /mnt/client
sudo gluster volume stop vol --mode=script
sudo gluster volume delete vol --mode=script
}

function set_read_subvolume {
sudo gluster volume set vol cluster.read-subvolume vol-client-$1
assert_success $?
}

function disable_self_heal {
sudo gluster volume set vol cluster.data-self-heal off
assert_success $?
sudo gluster volume set vol cluster.metadata-self-heal off
assert_success $?
sudo gluster volume set vol cluster.entry-self-heal off
assert_success $?
}

function assert_are_equal {
AREQUAL='/home/pranithk/workspace/tools/areqal/arequal/arequal-checksum'
sudo rm -rf /tmp/{0,1,2,3}/.landfill
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
sudo touch file
sudo setfattr -n trusted.gfid -v 0sBfz5vAdHTEK1GZ99qjqTIg== /tmp/0/file
sudo find /mnt/client/file | xargs stat
assert_failure $?
reset_test_bed

echo "3) Test should succeed for a good entry"
init_test_bed 3
sudo touch afr_success_3.txt
assert_success $?
sudo dd if=/dev/urandom of=afr_success_3.txt bs=1M count=10
assert_success $?
sudo ls -l afr_success_3.txt
assert_success $?
[ `ls -l afr_success_3.txt | awk '{ print $5}'` = 10485760 ]
assert_success $?
reset_test_bed


echo "4) Test if the source is selected based on entry transaction for directory"
init_test_bed 4
sudo mkdir -p abc/def
assert_success $?
set_read_subvolume 3
disable_self_heal
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-1.pid`
sudo touch abc/def/ghi
sudo gluster volume start vol force
assert_success $?
sleep 20
[ `ls abc/def/` = "ghi" ]
assert_success $?
reset_test_bed

echo "5) Test if the source is selected based on data transaction for reg file"
init_test_bed 5
set_read_subvolume 3
disable_self_heal
sudo dd if=/dev/urandom of=afr_success_5.txt bs=1M count=1
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-1.pid`
sudo dd if=/dev/urandom of=afr_success_5.txt bs=1M count=10
assert_success $?
sudo gluster volume start vol force
assert_success $?
sleep 20
[ `ls -l afr_success_5.txt | awk '{ print $5}'` = 10485760 ]
assert_success $?
reset_test_bed

echo "6) Test if the source is selected based on metadata transaction for linkfile"
init_test_bed 6
set_read_subvolume 3
disable_self_heal
sudo touch afr_success_6.txt
assert_success $?
sudo ln -s afr_success_6.txt link_to_afr_success_6.txt
ls -l
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-1.pid`
sudo dd if=/dev/urandom of=link_to_afr_success_6.txt bs=1M count=10
assert_success $?
ls -l
sudo chown -h pranithk:pranithk link_to_afr_success_6.txt
ls -l
sudo gluster volume start vol force
assert_success $?
sleep 20
[ `ls -l link_to_afr_success_6.txt | awk '{ print $3}'` = pranithk ]
assert_success $?
[ `ls -l link_to_afr_success_6.txt | awk '{ print $4}'` = pranithk ]
assert_success $?
reset_test_bed

echo "7) Self-heal: Enoent + Success"
init_test_bed 7
sudo mkdir -p abc/def abc/ghi
sudo dd if=/dev/urandom of=abc/file_abc.txt bs=1M count=2
sudo dd if=/dev/urandom of=abc/def/file_abc_def_1.txt bs=1M count=2
sudo dd if=/dev/urandom of=abc/def/file_abc_def_2.txt bs=1M count=3
sudo dd if=/dev/urandom of=abc/ghi/file_abc_ghi.txt bs=1M count=4
assert_success $?

sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
sudo rm -rf abc/ghi
sudo truncate -s 0 abc/def/file_abc_def_1.txt
sudo chown  pranithk:pranithk abc/def/file_abc_def_2.txt
sudo mkdir -p def/ghi jkl/mno
sudo dd if=/dev/urandom of=def/ghi/file1.txt bs=1M count=2
sudo dd if=/dev/urandom of=def/ghi/file2.txt bs=1M count=3
sudo dd if=/dev/urandom of=jkl/mno/file.txt bs=1M count=4
sudo chown  pranithk:pranithk def/ghi/file2.txt
sudo gluster volume start vol force
assert_success $?
sleep 20
sudo find /mnt/client | xargs stat
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
sudo touch file
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
sudo rm -f file
sudo mkdir file
sudo gluster volume start vol force
sleep 20
sudo find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

echo "9.b) Self-heal: Success + permissions differ"
init_test_bed 9b
sudo touch file
sudo chmod 666 file
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
sudo chmod 777 file
sudo gluster volume start vol force
sleep 20
sudo find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

echo "9.c) Self-heal: Success + ownership differs"
init_test_bed 9c
sudo touch file
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
sudo chown pranithk:pranithk file
sudo gluster volume start vol force
sleep 20
sudo find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

echo "9.d) Self-heal: Success + size differs"
echo "increase file size test"
init_test_bed 9d
sudo touch file
sudo echo "write1" > file
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
sudo echo "write2" >> file
sudo gluster volume start vol force
sleep 20
sudo find /mnt/client | xargs stat
ls -lR /mnt/client
ls -lR /tmp/{0,1,2,3}/
echo "decrease file size test"
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
sudo truncate -s 0 file
sudo gluster volume start vol force
sleep 20
sudo find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

echo "9.e) Self-heal: Success + gfid differs"
init_test_bed 9e
sudo touch file
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
sudo rm -f file
sudo touch file
sudo gluster volume start vol force
sleep 20
sudo find /mnt/client | xargs stat
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/file
assert_are_equal
reset_test_bed

echo "10.a) Self-heal: xattr data pending"
init_test_bed 10a
sudo touch file
sudo echo "write1" > file
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
sudo echo "write2" > file
sudo gluster volume start vol force
sleep 20
sudo find /mnt/client | xargs stat
assert_are_equal
reset_test_bed

echo "10.b) Self-heal: xattr metadata pending"
init_test_bed 10b
sudo touch file
sudo chown pranithk:pranithk file
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
sudo chown root:root file
sudo chown pranithk:pranithk file
sudo gluster volume start vol force
sleep 20
sudo find /mnt/client | xargs stat
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/file
assert_are_equal
reset_test_bed

echo "10.c) Self-heal: xattr entry pending"
init_test_bed 10c
sudo mkdir -p abc/def
sudo kill -9 `cat /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-0.pid /etc/glusterd/vols/vol/run/$HOSTNAME-tmp-2.pid`
sudo mkdir abc/ghi
sudo mkdir abc/jkl
sudo gluster volume start vol force
sleep 20
sudo find /mnt/client | xargs stat
ls -l /tmp/{0,1,2,3}/abc
assert_are_equal
reset_test_bed

echo "11a) mark source with the lowest uuid"
init_test_bed 11
sudo touch abc
sudo chown pranithk:pranithk abc
sudo chown root:root /tmp/1/abc
ls -l abc
ls -l /tmp/{0,1,2,3}/abc
reset_test_bed

echo "11b) mark source with the lowest uuid on multiple nodes"
init_test_bed 11
sudo touch abc
sudo chown pranithk:pranithk abc
sudo chown root:root /tmp/1/abc
sudo chown root:root /tmp/3/abc
sudo find /mnt/client | xargs stat
ls -l /tmp/{0,1,2,3}/abc
assert_are_equal
reset_test_bed

echo "12) Make all the replicas fools, it should pick biggest of fools as source"
init_test_bed 12
sudo touch abc
sudo setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAEAAAAA /tmp/0/abc
sudo setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAEAAAAA /tmp/0/abc
sudo setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAEAAAAA /tmp/0/abc
sudo setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAEAAAAA /tmp/0/abc

sudo setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAIAAAAA /tmp/1/abc
sudo setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAEAAAAA /tmp/1/abc
sudo setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAEAAAAA /tmp/1/abc
sudo setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAIAAAAA /tmp/1/abc

sudo setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAEAAAAA /tmp/2/abc
sudo setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAEAAAAA /tmp/2/abc
sudo setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAEAAAAA /tmp/2/abc
sudo setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAEAAAAA /tmp/2/abc

sudo setfattr -n trusted.afr.vol-client-0 -v 0sAAAAAAAAAAEAAAAA /tmp/3/abc
sudo setfattr -n trusted.afr.vol-client-1 -v 0sAAAAAAAAAAIAAAAA /tmp/3/abc
sudo setfattr -n trusted.afr.vol-client-2 -v 0sAAAAAAAAAAIAAAAA /tmp/3/abc
sudo setfattr -n trusted.afr.vol-client-3 -v 0sAAAAAAAAAAEAAAAA /tmp/3/abc
ls -l abc
getfattr -d -m "trusted" -e hex /tmp/{0,1,2,3}/abc
assert_are_equal
reset_test_bed

