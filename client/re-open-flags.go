//807976
package main
import (
        "os"
        "os/exec"
        "strings"
        "fmt"
        "time"
        "bytes"
)

var hostname string
var uname string

func get1mbuf (str string) *bytes.Buffer {
        buf1m := bytes.NewBufferString("");
        for i := 0; i < (1024*1024); i++ {
                fmt.Fprint(buf1m, str);
        }
        return buf1m
}

func run (s string) (o string, e error) {
        fields := strings.Fields (s)
        fmt.Println ("exec", s)
        cmd := exec.Command(fields[0], fields[1:]...)
        output, err := cmd.CombinedOutput()
        fmt.Println (string(output))
        return string(output), err
}

func init_test_bed () error {
        run ("glusterd")
        run ("rm -rf /tmp/0")
        run ("umount /mnt/client")
        _, err := run ("/usr/local/sbin/gluster volume create vol "+hostname+":/tmp/0 --mode=script")
        if (err != nil) {
                return err
        }
        run ("/usr/local/sbin/gluster volume set vol self-heal-daemon off")
        run ("/usr/local/sbin/gluster volume set vol stat-prefetch off")
        _, err = run ("/usr/local/sbin/gluster volume start vol")
        if (err != nil) {
                return err
        }
        run ("/usr/local/sbin/gluster volume set vol cluster.background-self-heal-count 0")
        run ("/usr/local/sbin/gluster volume set vol diagnostics.client-log-level DEBUG")
        _, err = run ("/usr/local/sbin/glusterfs --volfile-id=/vol --volfile-server="+hostname+" /mnt/client --attribute-timeout=0 --entry-timeout=0")
        if (err != nil) {
                return err
        }
        os.Chdir("/mnt/client")
        return nil
}

func reset_test_bed () {
        os.Chdir("/")
        run("umount /mnt/client")
        run("/usr/local/sbin/gluster volume stop vol --mode=script")
        run("/usr/local/sbin/gluster volume delete vol --mode=script")
        run("rm -rf /tmp/0")
}

func bring_volume_down () {
        run("/usr/local/sbin/gluster volume stop vol --mode=script")
}

func bring_volume_up () {
        run("/usr/local/sbin/gluster volume start vol --mode=script")
}

func wait_for_client_brick_connection () {
        time.Sleep(20e9)
}

func test_o_trunc_and_o_append () {
        fname := "a.txt"
        flags := os.O_CREATE|os.O_TRUNC|os.O_EXCL|os.O_APPEND|os.O_RDWR|os.O_SYNC
        f, err := os.OpenFile (fname, flags, 0666)
        if (err != nil) {
                fmt.Println ("%v", err);
                return
        }
        run("chown "+uname+":"+uname+" "+fname)
        buf := get1mbuf("a")
        _, err  = f.WriteString (buf.String())
        if (err != nil) {
                fmt.Println(err)
                return
        }
        f.Seek(0, os.SEEK_SET)
        bring_volume_down ()
        bring_volume_up ()
        wait_for_client_brick_connection ()
        //In Old versions File would have gone to EBADFD as re-open would fail with EEXIST
        //Writes will fail in backend but error won't be propagated up, so
        //close and re-open to see if the contents are written correctly
        readdata := make([]byte, 1024*1024)
        _, err = f.Read (readdata)
        if (err != nil) {
                fmt.Println(err)
                return
        }
        if (buf.String() != string(readdata)) {
                fmt.Println ("test_o_trunc_and_o_append Failed")
                return
        } else {
                fmt.Println ("test_o_trunc_and_o_append Passed")
        }
        _, err = f.WriteString (buf.String())
        if (err != nil) {
                fmt.Println(err)
                return
        }

        readdata1 := make([]byte, 1024*1024*2)
        f.Seek(0, os.SEEK_SET)
        bring_volume_down ()
        bring_volume_up ()
        wait_for_client_brick_connection ()
        f.Close()
        f, err = os.Open (fname)
        if (err != nil) {
                fmt.Println ("%v", err);
                return
        }
        _, err = f.Read (readdata1)
        defer f.Close()
        if (err != nil) {
                fmt.Println(err)
                return
        }

        if ((buf.String() + buf.String()) != string(readdata1)) {
                fmt.Println ("test_o_trunc_and_o_append Failed")
                return
        } else {
                fmt.Println ("test_o_trunc_and_o_append Passed")
        }
        group, err := run("stat --printf %G "+fname)
        if (err != nil) {
                fmt.Println(err)
                return
        }
        if (group != uname) {
                fmt.Println("test failed")
        } else {
                fmt.Println("test passed")
        }
        user, err := run("stat --printf %U "+fname)
        if (err != nil) {
                fmt.Println(err)
                return
        }
        if (user != uname) {
                fmt.Println("test failed")
        } else {
                fmt.Println("test passed")
        }
}

func main () {
        hostname = os.Args[1]
        uname = os.Args[2]
        fmt.Println(hostname)
        err := init_test_bed ()
        if (err != nil) {
                return
        }
        test_o_trunc_and_o_append ()
        reset_test_bed ()
}
