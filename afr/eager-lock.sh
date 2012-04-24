gluster volume create vol replica 2 `hostname`:/tmp/1 `hostname`:/tmp/2 --mode=script
gluster volume set vol eager-lock on
gluster volume start vol
mount -t glusterfs `hostname`:/vol /mnt/client
cd /mnt/client
for i in `seq 1 10`; do dd of=1 if=/dev/zero bs=1M count=10; done
cd
umount /mnt/client
gluster volume stop vol --mode=script
gluster volume delete vol --mode=script
rm -rf /tmp/1 /tmp/2
