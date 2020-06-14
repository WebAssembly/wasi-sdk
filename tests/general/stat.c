#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <dir>\n", argv[0]);
        return EXIT_FAILURE;
    }

    char *filename;
    int n = asprintf(&filename, "%s/file", argv[1]);
    assert(n > 0);

    n = creat(filename, S_IRUSR|S_IWUSR);
    assert(n >= 0);

    char *linkname;
    n = asprintf(&linkname, "%s/symlink", argv[1]);
    assert(n > 0);

    n = symlink("file", linkname);
    assert(n == 0);

    struct stat file_statbuf;
    struct stat link_statbuf;

    // Test stat.

    n = stat(filename, &file_statbuf);
    assert(n == 0);
    assert(file_statbuf.st_size == 0);
    assert(S_ISREG(file_statbuf.st_mode));

    n = stat(linkname, &link_statbuf);
    assert(n == 0);
    assert(link_statbuf.st_size == 0);
    assert(S_ISREG(link_statbuf.st_mode));

    assert(file_statbuf.st_dev == link_statbuf.st_dev);

    // Clear out the access time fields, and they should be the same.
    memset(&file_statbuf.st_atim, 0, sizeof(struct timespec));
    memset(&link_statbuf.st_atim, 0, sizeof(struct timespec));
    assert(memcmp(&file_statbuf, &link_statbuf, sizeof(struct stat)) == 0);

    // Test lstat.

    n = lstat(filename, &file_statbuf);
    assert(n == 0);
    assert(file_statbuf.st_size == 0);
    assert(S_ISREG(file_statbuf.st_mode));

    n = lstat(linkname, &link_statbuf);
    assert(n == 0);
    /*
    TODO: Currently fails under wasmtime 0.16.0.  Find some way
    to disable this test just under wasmtime.
    assert(link_statbuf.st_size != 0);
    assert(S_ISLNK(link_statbuf.st_mode));

    assert(file_statbuf.st_dev == link_statbuf.st_dev);
    assert(link_statbuf.st_ino != file_statbuf.st_ino);
    */

    n = unlink(filename);
    assert(n == 0);
    n = unlink(linkname);
    assert(n == 0);

    free(filename);
    free(linkname);

    return 0;
}
