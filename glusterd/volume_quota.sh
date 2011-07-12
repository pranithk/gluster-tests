sudo gluster volume create vol `hostname`:/tmp/1
sudo gluster volume start vol
sudo umount /mnt/client
sudo mount -t glusterfs `hostname`:/vol /mnt/client
sleep 5
cd /mnt/client; for i in {1..30}; do sudo dd if=/dev/zero of=$i.file bs=256KB count=1; done; cd -;
sudo gluster volume quota vol enable
sudo gluster volume quota vol limit-usage / 1GB
sudo gluster volume quota vol list
#sudo gluster volume quota vol disable
#sudo gluster volume stop vol
#sudo gluster volume delete vol
sudo gluster volume info
