import itertools
import os
import time
import xattr
import sys

dirgfid1='0sOY6EK8DrQ8abSTjfJYBFAw=='
dirgfid2='0sdr37R7h+S5izpclI2uRsLQ=='
filegfid1='0s/vNgfCTpT8q9UuOyhuSP2Q=='
filegfid2='0s8Qu6sTB3RUO+Mdfhegb3SA=='
volname="vol"
num_replicas=2
replicas=['/tmp/0/', '/tmp/1/']

def execute (cmd):
        status = os.system ("echo \"" + cmd +"\" && " +cmd)
        return

def execute_print (cmd):
        status = os.system ("echo \"" + cmd+"\"")
        return

def init_test_bed ():
        os.chdir ("/home/pranith")
        execute ("sudo umount /mnt/client")
        execute ("sudo gluster volume create vol replica 2 `hostname`:/tmp/0 `hostname`:/tmp/1 ")
        execute ("sudo gluster volume set vol performance.quick-read off")
        execute ("sudo gluster volume set vol performance.io-cache off")
        execute ("sudo gluster volume set vol performance.write-behind off")
        execute ("sudo gluster volume set vol performance.stat-prefetch off")
        execute ("sudo gluster volume set vol performance.read-ahead off")
        execute ("sudo gluster volume set vol diagnostics.client-log-level DEBUG")
        disable_self_heal ()
        execute ("sudo gluster volume start vol")
        execute ("sleep 5")
#        execute ("sudo valgrind --leak-check=yes --log-file=/etc/glusterd/valgrind$1.log /usr/local/sbin/glusterfs --log-level=INFO --volfile-id=/vol --volfile-server=localhost /mnt/client --attribute-timeout=0 --entry-timeout=0")
        execute ("sudo /usr/local/sbin/glusterfs --volfile-id=/vol --volfile-server=localhost /mnt/client --attribute-timeout=0 --entry-timeout=0")
        #time.sleep (20)
        os.chdir ("/mnt/client")
        execute ("mount | grep client")
        execute_print ( "-----------")
        execute_print ( os.getcwd())
        return


def reset_test_bed ():
        os.chdir ("/home/pranith")
        execute ("sudo umount /mnt/client")
        execute ("sudo gluster volume stop vol --mode=script")
        execute ("sudo gluster volume delete vol --mode=script")
        execute ("rm -rf /tmp/0 /tmp/1")
        return

def disable_self_heal ():
        execute ("sudo gluster volume set vol cluster.data-self-heal off")
        execute ("sudo gluster volume set vol cluster.metadata-self-heal off")
        execute ("sudo gluster volume set vol cluster.entry-self-heal off")


def generate_missing_file_enumerations (enumerations):
        xattr_states=['plain', 'source']
        missing_file_states=['delete', 'plain']
        for i in xrange(0, num_replicas):
                dir_xattrs=[]
                for x in xattr_states[:]:
                        dir_xattrs.append (x+"-dir-"+str(i))
                file_missing=[]
                for g in missing_file_states[:]:
                        file_missing.append (g+"-file-"+str(i))
                enumerations.append(dir_xattrs)
                enumerations.append(file_missing)
        return

def dir_gfids_conflicting (a):
        if a['dir0_gfid'] != 'none' and a['dir1_gfid'] != 'none' and a['dir0_gfid'] != a['dir1_gfid']:
                return 1
        return 0

def dir_xattrs_conflicting (a):
        if a['dir0_xattr'] == a['dir1_xattr'] == 'source':
                return 1
        return 0

def dirs_conflicting (a):
        if dir_gfids_conflicting (a):
                return 1
        if dir_xattrs_conflicting (a):
                return 1
        return 0

def file_gfids_conflicting (a):
        if a['file0_gfid'] != 'none' and a['file1_gfid'] != 'none' and a['file0_gfid'] != a['file1_gfid']:
                return 1
        return 0

def file_xattrs_conflicting (a):
        if a['file0_xattr'] == a['file1_xattr'] == 'source':
                return 1
        return 0

def files_conflicting (a):
        if file_gfids_conflicting (a):
                return 1
        if file_xattrs_conflicting (a):
                return 1
        return 0

def no_conflict_resultant_file (a):
        if a['file0_xattr'] == 'source' and a['file0_gfid'] == 'none':
                        return ('EQUAL_XATTR', 'none')
        if a['file1_xattr'] == 'source' and a['file1_gfid'] == 'none':
                        return ('EQUAL_XATTR', 'none')
        if a['file0_xattr'] == 'source':
                        return ('EQUAL_XATTR', a['file0_gfid'])
        if a['file1_xattr'] == 'source':
                        return ('EQUAL_XATTR', a['file1_gfid'])
        if a['file0_xattr'] == 'plain' and a['file1_xattr'] == 'plain':
                if a['file0_gfid'] != 'none':
                        return ('EQUAL_XATTR', a['file0_gfid'])
                elif a['file1_gfid'] != 'none':
                        return ('EQUAL_XATTR', a['file1_gfid'])
                else:
                        return ('EQUAL_XATTR', 'none')
        return ('BAD', 'BAD')

def xattr_conflict_resultant_file (a):
        if a['file0_gfid'] == 'none' and a['file1_gfid'] == 'none':
                return ('CONFLICT_XATTR', 'none')
        if a['file0_gfid'] != 'none':
                return ('CONFLICT_XATTR', a['file0_gfid'])
        if a['file1_gfid'] != 'none':
                return ('CONFLICT_XATTR', a['file1_gfid'])
        return ('BAD', 'BAD')

def gfid_enumeration_result (enumeration):
        a = {'dir0_xattr':enumeration[0].split('-')[0], 'file0_xattr':enumeration[1].split('-')[0], 'dir0_gfid':enumeration[2].split('-')[0], 'file0_gfid':enumeration[3].split('-')[0], 'dir1_xattr':enumeration[4].split('-')[0], 'file1_xattr':enumeration[5].split('-')[0], 'dir1_gfid':enumeration[6].split('-')[0], 'file1_gfid':enumeration[7].split('-')[0]}
        execute_print (str(a));
        if dirs_conflicting (a) == 1:
                if file_gfids_conflicting (a) == 1:
                        return ('ERROR', (a['dir0_xattr'], a['file0_xattr'], a['dir0_gfid'], a['file0_gfid'], a['dir1_xattr'], a['file1_xattr'], a['dir1_gfid'], a['file1_gfid']))
                elif file_xattrs_conflicting (a) == 1:
                        return ('ERROR', (a['dir0_xattr'], a['file0_xattr'], a['dir0_gfid'], a['file0_gfid'], a['dir1_xattr'], a['file1_xattr'], a['dir1_gfid'], a['file1_gfid']))
                else:
                        (f_xattr, f_gfid) = no_conflict_resultant_file(a)
                        return ('SUCCESS', (a['dir0_xattr'], f_xattr, a['dir0_gfid'], f_gfid, a['dir1_xattr'], f_xattr, a['dir1_gfid'], f_gfid))
        else:
                if a['dir0_xattr'] == 'source':
                        if file_gfids_conflicting (a) == 1:
                                return ('SUCCESS', (a['dir0_xattr'], 'EQUAL_XATTR', a['dir0_gfid'], a['file0_gfid'], a['dir1_xattr'], 'EQUAL_XATTR', a['dir1_gfid'], a['file0_gfid']))
                if a['dir1_xattr'] == 'source':
                        if file_gfids_conflicting (a) == 1:
                                return ('SUCCESS', (a['dir0_xattr'], 'EQUAL_XATTR', a['dir0_gfid'], a['file1_gfid'], a['dir1_xattr'], 'EQUAL_XATTR', a['dir1_gfid'], a['file1_gfid']))
                if file_xattrs_conflicting (a) == 1:
                        return ('ERROR', (a['dir0_xattr'], a['file0_xattr'], a['dir0_gfid'], a['file0_gfid'], a['dir1_xattr'], a['file1_xattr'], a['dir1_gfid'], a['file1_gfid']))
                if file_gfids_conflicting (a) == 1:
                        return ('ERROR', (a['dir0_xattr'], a['file0_xattr'], a['dir0_gfid'], a['file0_gfid'], a['dir1_xattr'], a['file1_xattr'], a['dir1_gfid'], a['file1_gfid']))
                (f_xattr, f_gfid) = no_conflict_resultant_file(a)
                return ('SUCCESS', (a['dir0_xattr'], f_xattr, a['dir0_gfid'], f_gfid, a['dir1_xattr'], f_xattr, a['dir1_gfid'], f_gfid))
        return ('BAD', 'BAD')

def generate_gfid_enumerations (enumerations):
        xattr_states=['plain', 'source']
        gfid_states=['none', 'gfid1', 'gfid2']

        for i in xrange(0, num_replicas):
                dir_xattrs=[]
                file_xattrs=[]
                for x in xattr_states[:]:
                        dir_xattrs.append (x+"-dir-"+str(i))
                        file_xattrs.append (x+"-file-"+str(i))
                dir_gfids=[]
                file_gfids=[]
                for g in gfid_states[:]:
                        dir_gfids.append (g+"-dir-"+str(i))
                        file_gfids.append (g+"-file-"+str(i))
                enumerations.append(dir_xattrs)
                enumerations.append(file_xattrs)
                enumerations.append(dir_gfids)
                enumerations.append(file_gfids)
        return

def perform_conflict_xattr_action (replica_dirs, d, f, attribute):
        execute_print ( "performing action: " +str(replica_dirs)+" "+ d +" " + f +" " +attribute)
        [attr, dir_file, rep_num] = attribute.split('-')
        if attr=="plain" or attr=="none":
                return
        if dir_file == "dir" and (attr=="gfid1" or attr == "gfid2"):
                return
        if dir_file == "dir":
                obj=d
        if dir_file == "file":
                obj=d+"/"+f
        if attr=="source":
                for i in xrange(0, num_replicas):
                        if int(rep_num) == i:
                                execute("sudo setfattr -n trusted.afr."+volname+"-client-"+str(i)+" -v 0sAAAAAAAAAAAAAAAA "+replica_dirs[int(rep_num)]+obj)
                                continue
                        if dir_file == "file":
                                execute("sudo setfattr -n trusted.afr."+volname+"-client-"+str(i)+" -v 0sAAAAAQAAAAEAAAAA "+replica_dirs[int(rep_num)]+obj)
                        if dir_file == "dir":
                                execute("sudo setfattr -n trusted.afr."+volname+"-client-"+str(i)+" -v 0sAAAAAAAAAAAAAAAL "+replica_dirs[int(rep_num)]+obj)
        gfid_val = ""
        if attr=="gfid1" and dir_file == "dir":
                gfid_val = dirgfid1
        if attr=="gfid2" and dir_file == "dir":
                gfid_val = dirgfid2
        if attr=="gfid1" and dir_file == "file":
                gfid_val = filegfid1
        if attr=="gfid2" and dir_file == "file":
                gfid_val = filegfid2
        if gfid_val != "":
                execute("sudo setfattr -n trusted.gfid  -v "+gfid_val+" "+replica_dirs[int(rep_num)]+obj)
        return

def perform_action (replica_dirs, d, f, attribute):
        execute_print ( "performing action: " +str(replica_dirs)+" "+ d +" " + f +" " +attribute)
        [attr, dir_file, rep_num] = attribute.split('-')
        if attr=="plain" or attr=="none":
                return
        if dir_file == "dir":
                obj=d
        if dir_file == "file":
                obj=d+"/"+f
        if attr=="delete":
                execute("sudo rm -f "+replica_dirs[int(rep_num)]+obj)
                return
        if attr=="source":
                for i in xrange(0, num_replicas):
                        if int(rep_num) == i:
                                execute("sudo setfattr -n trusted.afr."+volname+"-client-"+str(i)+" -v 0sAAAAAAAAAAAAAAAA "+replica_dirs[int(rep_num)]+obj)
                                continue
                        if dir_file == "file":
                                execute("sudo setfattr -n trusted.afr."+volname+"-client-"+str(i)+" -v 0sAAAAAQAAAAEAAAAA "+replica_dirs[int(rep_num)]+obj)
                        if dir_file == "dir":
                                execute("sudo setfattr -n trusted.afr."+volname+"-client-"+str(i)+" -v 0sAAAAAAAAAAAAAAAL "+replica_dirs[int(rep_num)]+obj)
        gfid_val = ""
        if attr=="gfid1" and dir_file == "dir":
                gfid_val = dirgfid1
        if attr=="gfid2" and dir_file == "dir":
                gfid_val = dirgfid2
        if attr=="gfid1" and dir_file == "file":
                gfid_val = filegfid1
        if attr=="gfid2" and dir_file == "file":
                gfid_val = filegfid2
        if gfid_val != "":
                execute("sudo setfattr -n trusted.gfid  -v "+gfid_val+" "+replica_dirs[int(rep_num)]+obj)
        return

def create_dirs_and_perform_action (replica_dirs, d, f, enumeration):
        execute("sudo mkdir /mnt/client/"+d)
        execute("sudo touch /mnt/client/"+d+"/"+f)
        for attribute in enumeration[:]:
                perform_action (replica_dirs, d, f, attribute)
        return

def verify_gfid (gfid, none_val, gfid_state):
        execute_print ("verifying gfid:"+" "+str(gfid_state)+" "+str(none_val)+" "+str(gfid))
        if gfid_state == 'none':
                gfid_state1 = none_val
        else:
                gfid_state1 = gfid_state
        if gfid_state1 == 'gfid1':
                return gfid == filegfid1
        if gfid_state1 == 'gfid2':
                return gfid == filegfid2
        if gfid_state1 == 'none':
                return gfid is None
        if gfid_state1 == 'new-gfid':
                return gfid is not None and gfid != filegfid1 and gfid != filegfid2
        return False

def verify_state (result, tmp0_gfid, tmp0_errno, tmp1_gfid, tmp1_errno):
        if result[0]=='ERROR':
                none = 'none'
        else:
                none = 'new-gfid'
        return verify_gfid (tmp0_gfid, none, result[1][3]) and verify_gfid (tmp1_gfid, none, result[1][7])


def xattr_conflict_create_dirs_and_perform_action (replica_dirs, d, f, enumeration, result):
        for r in replica_dirs[:]:
                execute("sudo mkdir "+r)
                execute("sudo mkdir "+r+d)
                execute("sudo touch "+r+d+"/"+f)
        init_test_bed ()
        os.chdir (d)
        for attribute in enumeration[:]:
                perform_conflict_xattr_action (replica_dirs, d, f, attribute)
        mount_errno = tmp0_errno = tmp1_errno = 0
        try:
                os.stat('/mnt/client/'+d+'/'+f)
        except OSError as (errno, strerror):
                mount_errno = errno
        except IOError as (errno, strerror):
                mount_errno = errno
        try:
                os.stat("/tmp/0/"+d+"/"+f)
                tmp0_gfid = '0s'+xattr.getxattr("/tmp/0/"+d+"/"+f, "trusted.gfid").encode('base64')
                tmp0_gfid = str(tmp0_gfid).rstrip('\n')
        except OSError as (errno, strerror):
                tmp0_errno = errno
                tmp0_gfid = None
        except IOError as (errno, strerror):
                tmp0_errno = errno
                tmp0_gfid = None
        try:
                os.stat("/tmp/1/"+d+"/"+f)
                tmp1_gfid = '0s'+xattr.getxattr("/tmp/1/"+d+"/"+f, "trusted.gfid").encode('base64')
                tmp1_gfid = str(tmp1_gfid).rstrip('\n')
        except OSError as (errno, strerror):
                tmp1_errno = errno
                tmp1_gfid = None
        except IOError as (errno, strerror):
                tmp1_errno = errno
                tmp1_gfid = None
        execute_print ('mount_errno:' + str(mount_errno))
        execute_print (str(result)+' '+str(tmp0_gfid)+" "+str(tmp0_errno)+" "+str (tmp1_gfid)+" "+str(tmp1_errno))
        if result[0] == 'SUCCESS' and mount_errno != 0:
                        execute_print ("failed")
                        sys,exit(-1)
        elif result[0] == 'ERROR' and mount_errno == 0:
                        execute_print ("failed")
                        sys,exit(-1)
        elif verify_state (result, tmp0_gfid, tmp0_errno,tmp1_gfid, tmp0_errno) == False:
                        execute_print ("failed")
                        sys,exit(-1)
        else:
                execute_print ('successful')
        reset_test_bed ()
        return

def gfid_create_dirs_and_perform_action (replica_dirs, d, f, enumeration, result):
        for r in replica_dirs[:]:
                execute("sudo mkdir "+r)
                execute("sudo mkdir "+r+d)
                execute("sudo touch "+r+d+"/"+f)
        for attribute in enumeration[:]:
                perform_action (replica_dirs, d, f, attribute)
        init_test_bed ()
        #os.chdir (d)
        #for r in replica_dirs[:]:
        #        xattr.removexattr (r+d, 'trusted.gfid')
        #        execute ("getfattr -d -n trusted.gfid " +r+d)
        mount_errno = tmp0_errno = tmp1_errno = 0
        try:
                os.stat('/mnt/client/'+d+'/'+f)
        except OSError as (errno, strerror):
                mount_errno = errno
        except IOError as (errno, strerror):
                mount_errno = errno

        try:
                os.stat("/tmp/0/"+d+"/"+f)
                tmp0_gfid = '0s'+xattr.getxattr("/tmp/0/"+d+"/"+f, "trusted.gfid").encode('base64')
                tmp0_gfid = str(tmp0_gfid).rstrip('\n')
        except OSError as (errno, strerror):
                tmp0_errno = errno
                tmp0_gfid = None
        except IOError as (errno, strerror):
                tmp0_errno = errno
                tmp0_gfid = None
        try:
                os.stat("/tmp/1/"+d+"/"+f)
                tmp1_gfid = '0s'+xattr.getxattr("/tmp/1/"+d+"/"+f, "trusted.gfid").encode('base64')
                tmp1_gfid = str(tmp1_gfid).rstrip('\n')
        except OSError as (errno, strerror):
                tmp1_errno = errno
                tmp1_gfid = None
        except IOError as (errno, strerror):
                tmp1_errno = errno
                tmp1_gfid = None
        execute_print ('mount_errno:' + str(mount_errno))
        execute_print (str(result)+' '+str(tmp0_gfid)+" "+str(tmp0_errno)+" "+str (tmp1_gfid)+" "+str(tmp1_errno))
        if result[0] == 'SUCCESS' and mount_errno != 0:
                        execute_print ("failed")
                        sys,exit(-1)
        elif result[0] == 'ERROR' and mount_errno == 0:
                        execute_print ("failed")
                        sys,exit(-1)
        elif verify_state (result, tmp0_gfid, tmp0_errno,tmp1_gfid, tmp0_errno) == False:
                        execute_print ("failed")
                        sys,exit(-1)
        else:
                execute_print ('successful')
        reset_test_bed ()
        return

gfid_enumerations=[]
generate_gfid_enumerations (gfid_enumerations)
j = 0
for i in itertools.product (*gfid_enumerations):
        if i[3]=='gfid2-file-0' or i[2]=='gfid2-dir-0':
                continue

        if i[2]=='gfid1-dir-0' and i[6]=='none-dir-1':
                continue
        if i[3]=='gfid1-file-0' and i[7]=='none-file-1':
                continue

        if i[2]=='none-dir-0' and i[6]=='gfid2-dir-1':
                continue
        if i[3]=='none-file-0' and i[7]=='gfid2-file-1':
                continue

        if i[0]=='source-dir-0' and i[4]=='plain-dir-1':
                continue
        if i[1]=='source-file-0' and i[5]=='plain-file-1':
                continue
        #all the above are duplicates.

        #need to write special test suit for this
        #since we are doing lookup based self-heal, the directories will conflict and give EIO even before the files are looked up
        if i[2]=='gfid1-dir-0' and i[6]=='gfid2-dir-1':
                continue
        j = j + 1
        result = gfid_enumeration_result(i)
        execute_print ( "test case:"+str(j)+" "+ str(i) + "\n"+ str(result))
        d = 'dir'+str(j)
        f = 'file'+str(j)
        if i[0]=='source-dir-0' and i[4]=='source-dir-1':
                xattr_conflict_create_dirs_and_perform_action (replicas, d, f, i, result)
        else:
                gfid_create_dirs_and_perform_action (replicas, d, f, i, result)
        execute_print ("\n**********************************\n")

execute_print ("\n----------------------------------\n")
missing_enumerations=[]
generate_missing_file_enumerations (missing_enumerations)
j = 0
for i in itertools.product (*missing_enumerations):
        if i[1]=='delete-file-0' and i[3]=="delete-file-1":
                continue
        if i[1]=='plain-file-0' and i[3]=="plain-file-1":
                continue
        j = j + 1
        execute_print ( "test case:"+str(j)+" "+ str(i))
        execute ("rm -rf /tmp/0 /tmp/1")
        init_test_bed ()
        create_dirs_and_perform_action (replicas, 'miss'+str(j), 'file'+str(j), i)
        execute ("ls -l /mnt/client/"+'miss'+str(j)+"/"+'file'+str(j))
        execute ("ls -l /tmp/0/"+'miss'+str(j)+"/"+'file'+str(j))
        execute ("ls -l /tmp/1/"+'miss'+str(j)+"/"+'file'+str(j))
        execute ("getfattr -d -m . /tmp/0/"+'miss'+str(j)+"/"+'file'+str(j))
        execute ("getfattr -d -m . /tmp/1/"+'miss'+str(j)+"/"+'file'+str(j))
        reset_test_bed ()


#test which will give EIO on parent dir gfid mismatches
execute_print ("test which will give EIO on parent dir gfid mismatches");
init_test_bed()
os.mkdir ("abc")
os.chdir ("abc")
os.system ("sudo touch pranith")
execute ("sudo kill -9 `cat /etc/glusterd/vols/vol/run/pranith-Inspiron-1440-tmp-0.pid")
execute ("sudo rm -rf /mnt/client/abc")
execute ("sudo mkdir /mnt/client/abc")
execute ("sudo touch /mnt/client/abc/pranith")
execute ("sudo gluster volume start vol force")
time.sleep (20)
execute ("sudo kill -9 `cat /etc/glusterd/vols/vol/run/pranith-Inspiron-1440-tmp-1.pid")
execute ("sudo rm -rf /mnt/client/abc")
execute ("sudo mkdir /mnt/client/abc")
execute ("sudo touch /mnt/client/abc/pranith")
execute ("sudo gluster volume start vol force")
time.sleep (20)
execute ("getfattr -d -m . /tmp/0/"+"abc")
execute ("getfattr -d -m . /tmp/1/"+"abc")
execute ("getfattr -d -m . /tmp/0/"+"abc/pranith")
execute ("getfattr -d -m . /tmp/1/"+"abc/pranith")
ret = os.system ("ls pranith")
if ret != 0:
        execute_print ("passed")
else:
        execute_print ("failed")
reset_test_bed ()
