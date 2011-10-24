import os
import time
import stat
import xattr
from socket import gethostname

HOSTNAME = gethostname()
if sys.argv[1] is None:
        print "Usage: please provide username"
        sys.exit(-1)

USER = sys.argv[1]
HOMEDIR = "/home/"+USER
def execute (cmd):
        status = os.system ("echo \"" + cmd +"\" && " +cmd)
        return

def execute_print (cmd):
        status = os.system ("echo \"" + cmd+"\"")
        return

def fop (fop, args):
        path = args[0]
        if args[1] == 1:
                try:
                        fobj = os.open (path, os.O_RDWR);
                except OSError as (errno, strerror):
                        result = "OS error({0}): {1}".format(errno, strerror)
                        return result
                except IOError as (errno, strerror):
                        result = "OS error({0}): {1}".format(errno, strerror)
                        return result
        else:
                fobj = path
        try:
                result = fop (fobj, *args[2:]);
        except OSError as (errno, strerror):
                result = "OS error({0}): {1}".format(errno, strerror)
        except IOError as (errno, strerror):
                result = "OS error({0}): {1}".format(errno, strerror)
        if args[1] == 1:
                os.close(fobj)
        return result


def init_test_bed ():
        os.chdir (HOMEDIR)
        execute ("sudo rm -rf /tmp/0 /tmp/1 /tmp/2 /tmp/3")
        execute ("sudo umount /mnt/client")
        execute ("sudo gluster volume create vol replica 4 `hostname`:/tmp/0 `hostname`:/tmp/1 `hostname`:/tmp/2 `hostname`:/tmp/3 --mode=script")
        execute ("sudo gluster volume set vol self-heal-daemon off")
        execute ("sudo gluster volume set vol client-log-level DEBUG")
        execute ("sudo gluster volume set vol performance.quick-read off")
        execute ("sudo gluster volume set vol performance.io-cache off")
        execute ("sudo gluster volume set vol performance.write-behind off")
        execute ("sudo gluster volume set vol performance.stat-prefetch off")
        execute ("sudo gluster volume set vol performance.read-ahead off")
        execute ("sudo gluster volume start vol")
        execute ("sleep 5")
#        execute ("sudo valgrind --leak-check=yes --log-file=/etc/glusterd/valgrind$1.log /usr/local/sbin/glusterfs --log-level=INFO --volfile-id=/vol --volfile-server=localhost /mnt/client --attribute-timeout=0 --entry-timeout=0")
        execute ("sudo /usr/local/sbin/glusterfs --volfile-id=/vol --volfile-server=localhost /mnt/client --attribute-timeout=0 --entry-timeout=0")
        os.chdir ("/mnt/client")
        execute ("mount | grep client")
        execute_print ("-----------")
        execute_print (os.getcwd())


def reset_test_bed ():
        os.chdir (HOMEDIR)
        execute ("sudo umount /mnt/client")
        execute ("sudo gluster volume stop vol --mode=script")
        execute ("sudo gluster volume delete vol --mode=script")


def set_read_subvolume (volnum):
        execute ("sudo gluster volume set vol cluster.read-subvolume vol-client-" + str(volnum))


def disable_self_heal ():
        execute ("sudo gluster volume set vol cluster.data-self-heal off")
        execute ("sudo gluster volume set vol cluster.metadata-self-heal off")
        execute ("sudo gluster volume set vol cluster.entry-self-heal off")


def read_child_is_set_and_up (inode_write, w_args, inode_read, r_args, verify, expected):
        execute ("sudo kill -9 `cat /etc/glusterd/vols/vol/run/"+HOSTNAME+"-tmp-0.pid /etc/glusterd/vols/vol/run/"+HOSTNAME+"-tmp-1.pid /etc/glusterd/vols/vol/run/"+HOSTNAME+"-tmp-2.pid`");
        fop (inode_write, w_args)
        execute ("sudo gluster volume start vol force")
        time.sleep (20)
        verify (fop (inode_read, r_args), expected)


def read_child_is_set_and_not_up (inode_write, w_args, inode_read, r_args, verify, expected):
        execute ("sudo kill -9 `cat /etc/glusterd/vols/vol/run/"+HOSTNAME+"-tmp-0.pid /etc/glusterd/vols/vol/run/"+HOSTNAME+"-tmp-1.pid /etc/glusterd/vols/vol/run/"+HOSTNAME+"-tmp-3.pid`");
        fop (inode_write, w_args)
        execute ("sudo gluster volume start vol force")
        time.sleep (20)
        execute ("sudo kill -9 `cat /etc/glusterd/vols/vol/run/"+HOSTNAME+"-tmp-2.pid`")
        verify (fop (inode_read, r_args), expected)
        execute ("sudo gluster volume start vol force")
        time.sleep (20)


def  two_children_one_not_up (inode_write, w_args, inode_read, r_args, verify, expected):
        execute ("sudo kill -9 `cat /etc/glusterd/vols/vol/run/"+HOSTNAME+"-tmp-0.pid  /etc/glusterd/vols/vol/run/"+HOSTNAME+"-tmp-2.pid`");
        fop (inode_write, w_args)
        execute ("sudo gluster volume start vol force")
        time.sleep (20)
        execute ("sudo kill -9 `cat /etc/glusterd/vols/vol/run/"+HOSTNAME+"-tmp-1.pid`")
        verify (fop (inode_read, r_args), expected)
        execute ("sudo gluster volume start vol force")
        time.sleep (20)


def  failover (inode_write, w_args, inode_read, r_args, verify, expected):
        fop (inode_write, w_args)
        verify (fop (inode_read, r_args), expected)

def  verify_stat (result, expected):
        fail = 0
        execute_print (str(result))
        if len(expected) <= 0 or expected[0] (result.st_mode) == 0:
                execute_print ("files mismatch"+str(expected)+ "result: "+str( result))
                fail = fail + 1
        if len(expected) <= 0 or (result.st_nlink, result.st_uid, result.st_gid, result.st_size) != (expected[1], expected[2], expected[3], expected[4]):
                fail = fail + 1
        if (fail != 0):
                execute("ls -l")
                execute ('find /tmp/0 | xargs getfattr -d -m .')
                execute ('find /tmp/1 | xargs getfattr -d -m .')
                execute ('find /tmp/2 | xargs getfattr -d -m .')
                execute ('find /tmp/3 | xargs getfattr -d -m .')
                execute_print ("stat verification failed+ expected: "+ str(expected)+ "result: "+ str(result))
        else:
                execute_print ("stat verification successful")


def verify_val (result, expected):
        if result != expected:
                execute ('ls -l')
                execute ('find /tmp/0 | xargs getfattr -d -m .')
                execute ('find /tmp/1 | xargs getfattr -d -m .')
                execute ('find /tmp/2 | xargs getfattr -d -m .')
                execute ('find /tmp/3 | xargs getfattr -d -m .')
                execute_print ("verification failed, expected: "+ str(expected)+ "result: "+ str(result))
        else:
                execute_print ("verification successful")

def verify_dirs (result, expected):
        if set(result) != set(expected):
                execute ('ls -l')
                execute ('find /tmp/0 | xargs getfattr -d -m .')
                execute ('find /tmp/1 | xargs getfattr -d -m .')
                execute ('find /tmp/2 | xargs getfattr -d -m .')
                execute ('find /tmp/3 | xargs getfattr -d -m .')
                execute_print ("verification failed, expected: "+ str(expected)+ "result: "+ str(result))
        else:
                execute_print ("verification successful")


execute_print ("test suit: read_child_is_set_and_up")
init_test_bed ()
disable_self_heal ()
set_read_subvolume (3)
read_child_is_set_and_up (os.mknod, ["file", 0, 0600, stat.S_IFREG], os.stat, ["file", 0], verify_stat, [stat.S_ISREG, 1, 0, 0, 0])
read_child_is_set_and_up (os.mknod, ["file1", 0, 0700, stat.S_IFIFO], os.access, ["file1", 0, os.R_OK], verify_val, True)
read_child_is_set_and_up (os.link, ["file", 0, "hlinkfile"], os.stat, ["hlinkfile", 0], verify_stat, [stat.S_ISREG, 2, 0, 0, 0])
read_child_is_set_and_up (xattr.setxattr, ["hlinkfile", 0, "trusted.abc", "def"], xattr.getxattr, ["hlinkfile", 0, "trusted.abc"], verify_val, "def")
read_child_is_set_and_up (os.symlink, ["file", 0, "slinkfile"], os.readlink, ["slinkfile", 0], verify_val, "file")
read_child_is_set_and_up (os.write, ["file", 1, "Write success\n"], os.read, ["file", 1, 555], verify_val, "Write success\n")
read_child_is_set_and_up (os.mkdir, ["dir1", 0, 0640], os.listdir, ["/mnt/client", 0], verify_dirs, ['file', 'hlinkfile', 'slinkfile', 'dir1', 'file1'])
read_child_is_set_and_up (os.chmod, ["file", 0, stat.S_IRWXG|stat.S_IRWXU|stat.S_IRWXO], os.stat, ["file", 0], verify_stat, [stat.S_ISREG, 2, 0, 0, 14])
read_child_is_set_and_up (os.rename, ["file", 0, "file-renamed"], os.stat, ["file-renamed", 0], verify_stat, [stat.S_ISREG, 2, 0, 0, 14])
reset_test_bed ()

execute_print ("test suit: read_child_is_set_and_not_up")
init_test_bed ()
disable_self_heal ()
set_read_subvolume (2)
read_child_is_set_and_not_up (os.mknod, ["file", 0, 0600, stat.S_IFREG], os.stat, ["file", 0], verify_val, "OS error(2): No such file or directory")
read_child_is_set_and_not_up (os.mknod, ["file1", 0, 0700, stat.S_IFIFO], os.access, ["file1", 0, os.R_OK], verify_val, False)
read_child_is_set_and_not_up (os.link, ["file", 0, "hlinkfile"], os.stat, ["file", 0], verify_val, "OS error(2): No such file or directory")
read_child_is_set_and_not_up (xattr.setxattr, ["hlinkfile", 0, "trusted.abc", "def"], xattr.getxattr, ["hlinkfile", 0, "trusted.abc"], verify_val, "OS error(2): No such file or directory")
read_child_is_set_and_not_up (os.symlink, ["file", 0, "slinkfile"], os.readlink, ["slinkfile", 0], verify_val, "OS error(2): No such file or directory")
read_child_is_set_and_not_up (os.write, ["file", 1, "Write success\n"], os.read, ["file", 1, 555], verify_val, "OS error(2): No such file or directory")
read_child_is_set_and_not_up (os.mkdir, ["dir1", 0, 0640], os.listdir, ["/mnt/client", 0], verify_dirs, [])
read_child_is_set_and_not_up (os.chmod, ["file", 0, stat.S_IRWXG|stat.S_IRWXU|stat.S_IRWXO], os.stat, ["file", 0], verify_val, "OS error(2): No such file or directory")
read_child_is_set_and_not_up (os.rename, ["file", 0, "file-renamed"], os.stat, ["file-renamed", 0], verify_val, "OS error(2): No such file or directory")
reset_test_bed ()

execute_print ("test suit: two_children_one_not_up")
init_test_bed ()
disable_self_heal ()
two_children_one_not_up (os.mknod, ["file", 0, 0600, stat.S_IFREG], os.stat, ["file", 0], verify_stat, [stat.S_ISREG, 1, 0, 0, 0])
two_children_one_not_up (os.mknod, ["file1", 0, 0700, stat.S_IFIFO], os.access, ["file1", 0, os.R_OK], verify_val, True)
two_children_one_not_up (os.link, ["file", 0, "hlinkfile"], os.stat, ["file", 0], verify_stat, [stat.S_ISREG, 2, 0, 0, 0])
two_children_one_not_up (xattr.setxattr, ["hlinkfile", 0, "trusted.abc", "def"], xattr.getxattr, ["hlinkfile", 0, "trusted.abc"], verify_val, "def")
two_children_one_not_up (os.symlink, ["file", 0, "slinkfile"], os.readlink, ["slinkfile", 0], verify_val, "file")
two_children_one_not_up (os.write, ["file", 1, "Write success\n"], os.read, ["file", 1, 555], verify_val, "Write success\n")
two_children_one_not_up (os.mkdir, ["dir1", 0, 0640], os.listdir, ["/mnt/client", 0], verify_dirs, ['file', 'hlinkfile', 'slinkfile', 'dir1', 'file1'])
two_children_one_not_up (os.chmod, ["file", 0, stat.S_IRWXG|stat.S_IRWXU|stat.S_IRWXO], os.stat, ["file", 0], verify_stat, [stat.S_ISREG, 2, 0, 0, 14])
two_children_one_not_up (os.rename, ["file", 0, "file-renamed"], os.stat, ["file-renamed", 0], verify_stat, [stat.S_ISREG, 2, 0, 0, 14])
reset_test_bed ()

#FAILOVER SUCCESS this is done by patching the inode-read-fop_cbk to fail the first reply.
#init_test_bed ()
#execute ("sudo gluster volume set vol cluster.inode-read-fop-fail once")
#time.sleep (5);
#failover (os.mknod, ["file", 0, 0600, stat.S_IFREG], os.stat, ["file", 0], verify_stat, [stat.S_ISREG, 1, 0, 0, 0])
#failover (os.mknod, ["file1", 0, 0700, stat.S_IFIFO], os.access, ["file1", 0, os.R_OK], verify_val, True)
#failover (os.link, ["file", 0, "hlinkfile"], os.stat, ["file", 0], verify_stat, [stat.S_ISREG, 2, 0, 0, 0])
#failover (xattr.setxattr, ["hlinkfile", 0, "trusted.abc", "def"], xattr.getxattr, ["hlinkfile", 0, "trusted.abc"], verify_val, "def")
#failover (os.symlink, ["file", 0, "slinkfile"], os.readlink, ["slinkfile", 0], verify_val, "file")
#failover (os.write, ["file", 1, "Write success\n"], os.read, ["file", 1, 555], verify_val, "Write success\n")
#failover (os.mkdir, ["dir1", 0, 0640], os.listdir, ["/mnt/client", 0], verify_dirs, [])
#failover (os.chmod, ["file", 0, stat.S_IRWXG|stat.S_IRWXU|stat.S_IRWXO], os.stat, ["file", 0], verify_stat, [stat.S_ISREG, 2, 0, 0, 14])
#failover (os.rename, ["file", 0, "file-renamed"], os.stat, ["file-renamed", 0], verify_stat, [stat.S_ISREG, 2, 0, 0, 14])
#reset_test_bed ()
#
##FAILOVER FAILURE this is done by patching the inode-read-fop_cbk to fail all replies.
#init_test_bed ()
#execute ("sudo gluster volume set vol cluster.inode-read-fop-fail always")
#time.sleep (5);
#failover (os.mknod, ["file", 0, 0600, stat.S_IFREG], os.stat, ["file", 0], verify_val, "OS error(5): Input/output error")
#failover (os.mknod, ["file1", 0, 0700, stat.S_IFIFO], os.access, ["file1", 0, os.R_OK], verify_val, False)
#failover (os.link, ["file", 0, "hlinkfile"], os.stat, ["file", 0], verify_val, "OS error(5): Input/output error")
#failover (xattr.setxattr, ["hlinkfile", 0, "trusted.abc", "def"], xattr.getxattr, ["hlinkfile", 0, "trusted.abc"], verify_val, "OS error(5): Input/output error")
#failover (os.symlink, ["file", 0, "slinkfile"], os.readlink, ["slinkfile", 0], verify_val, None)
#failover (os.write, ["file", 1, "Write success\n"], os.read, ["file", 1, 555], verify_val, "OS error(5): Input/output error")
#failover (os.mkdir, ["dir1", 0, 0640], os.listdir, ["/mnt/client", 0], verify_dirs, [])
#failover (os.chmod, ["file", 0, stat.S_IRWXG|stat.S_IRWXU|stat.S_IRWXO], os.stat, ["file", 0], verify_val, "OS error(5): Input/output error")
#failover (os.rename, ["file", 0, "file-renamed"], os.stat, ["file-renamed", 0], verify_val, "OS error(5): Input/output error")
#time.sleep (3)
#reset_test_bed ()

#Afr fd-write-fops set the read-child if the read-child fails for some reason
execute_print ("test suit: Afr fd-write-fops set the read-child if the read-child fails for some reason")
init_test_bed ()
fd = 0
try:
        os.mknod("file", 0700, stat.S_IFREG)
        fd = os.open ("file", os.O_RDWR)
        os.write (fd, "Write success")
        os.fsync (fd)
        os.write (fd, "Write success")
        os.ftruncate (fd,0)
        os.close (fd)
        fd = os.open ("file1", os.O_RDWR|os.O_CREAT)
        os.close (fd)
	fd = 0
        if set(os.listdir("/mnt/client")) != set(['file', 'file1']):
                execute_print("fd-write-fops verification failure")
except OSError as (errno, strerror):
        execute_print ("OS error({0}): {1}".format(errno, strerror))
if fd != 0:
        os.close (fd)
reset_test_bed ()

#have one good brick and one bad brick, see if the inode-read fails then the operation fails
#This verifies that the fresh_children is correct
