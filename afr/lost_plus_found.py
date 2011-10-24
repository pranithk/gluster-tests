import os
import time
import xattr
import binascii
from socket import gethostname

HOSTNAME = gethostname()
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

def init_test_bed ():
        os.chdir (HOMEDIR)
        execute ("sudo rm -rf /home/gluster1 /home/gluster2")
        execute ("sudo umount /mnt/client")
        execute ("sudo gluster volume create vol replica 2 `hostname`:/home/gluster1 `hostname`:/home/gluster2 --mode=script")
        execute ("sudo gluster volume set vol self-heal-daemon off")
        execute ("sudo gluster volume set vol client-log-level DEBUG")
        execute ("sudo gluster volume set vol brick-log-level DEBUG")
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

def create_path (depth):
        for i in xrange (0, depth):
                #execute_print (str(i))
                os.mkdir('a')
                os.chdir('a')

def run_expunge_dir_depth (depth):
        execute_print ("running expunge for depth " + str (depth))
        orig_cwd = os.getcwd()
        execute_print ("orig dir: " + orig_cwd)
        create_path(depth)
        os.chdir('../')
        execute("kill -9 `cat /etc/glusterd/vols/vol/run/"+HOSTNAME+"-home-gluster1.pid`");
        os.rmdir('a')
        realcwd = os.getcwd()
        cwd = realcwd[len('/mnt/client/'):]
        execute_print ("cwd: " + cwd)
        execute_print (xattr.getxattr ("/home/gluster2/"+cwd, "trusted.afr.vol-client-0").encode('base64'))
        execute ("gluster volume start vol force")
        execute ("sleep 20")
        os.listdir ('.')
        os.chdir(orig_cwd)

def run_expunge_dirname (dirname):
        orig_cwd = os.getcwd()
        execute_print ("orig dir: " + orig_cwd)
        os.mkdir (dirname)
        execute("kill -9 `cat /etc/glusterd/vols/vol/run/"+HOSTNAME+"-home-gluster1.pid`");
        execute_print (binascii.b2a_hex (xattr.getxattr ("/home/gluster2/"+dirname, "trusted.gfid")))
        os.rmdir(dirname)
        execute_print (xattr.getxattr ("/home/gluster2/", "trusted.afr.vol-client-0").encode('base64'))
        execute ("gluster volume start vol force")
        execute ("sleep 20")
        os.listdir ('.')

init_test_bed()
uuid_buf_len = 36
namelen = (256 - uuid_buf_len)
run_expunge_dirname ('a' * namelen)
namelen = namelen - 1
run_expunge_dirname ('b' * namelen)
namelen = namelen - 1
run_expunge_dirname ('c' * namelen)
namelen = namelen - 1
run_expunge_dirname ('d' * namelen)
base_length = len ('/home/gluster1/.landfill/lost+found/')
depth = (4096 - base_length - uuid_buf_len) / 2
run_expunge_dir_depth (depth)
execute ("ls /home/gluster1/.landfill/lost+found")
#reset_test_bed ()
