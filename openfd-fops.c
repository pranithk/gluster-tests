#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <stdlib.h>

void
print_menu (void)
{
        char *menu = "----------------\n"
                     "0 - Exit\n"
                     "1 - Read from fd\n"
                     "2 - Write to fd\n"
                     "3 - Seek on fd\n"
                     "----------------\n";
        printf (menu);
}

size_t
scan_val (char *identifier)
{
        size_t  val = 0;
        printf ("Enter %s:", identifier);
        scanf ("%zu", &val);
        return val;
}

void
main (int argc, char **argv)
{
        int     fd = 0;
        int     ret = 0;
        int     option = 0;
        size_t  offset = 0;
        size_t  len = 0;
        char    *buf = NULL;
        int     seekval = 0;
        int     seekin = 0;

        if (argc < 2)
                goto out;
        fd = open (argv[1], O_CREAT|O_RDWR);
        if (fd < 0) {
                printf ("Failed to open %s, %s", argv[1], strerror (errno));
                goto out;
        }
        while (1) {
                if (buf) {
                        free (buf);
                        buf = NULL;
                }
                print_menu ();
                scanf ("%d", &option);
                switch (option) {
                case 0:
                        exit(0);
                        break;
                case 1:
                        len = scan_val ("len");
                        buf = calloc (len+1, 1);
                        buf[len] = 0;
                        ret = read (fd, buf, len);
                        if (ret < 0) {
                                printf ("Failed to read - %s", strerror (errno));
                                continue;
                        }
                        printf ("%s\n", buf);
                        break;
                case 2:
                        len = scan_val ("len");
                        buf = calloc (len + 1, 1);
                        buf[len] = 0;
                        memset (buf, '0', len);
                        ret = write (fd, buf, len);
                        if (ret < 0) {
                                printf ("Failed to write - %s", strerror (errno));
                                continue;
                        }
                        break;
                case 3:
                        offset = scan_val ("Offset");
                        seekin = scan_val ("seek-point (0 or 1 0r 2)");
                        switch (seekin) {
                        case 0:
                                seekval = SEEK_SET;
                                break;
                        case 1:
                                seekval = SEEK_CUR;
                                break;
                        case 2:
                                seekval = SEEK_END;
                                break;
                        }
                        lseek (fd, offset, seekval);
                }
        }
out:
        return;
}
