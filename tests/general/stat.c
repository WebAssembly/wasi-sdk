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

    assert(file_statbuf.st_dev == link_statbuf.st_dev);
    assert(file_statbuf.st_ino == link_statbuf.st_ino);
    assert(file_statbuf.st_mode == link_statbuf.st_mode);
    assert(file_statbuf.st_uid == link_statbuf.st_uid);
    assert(file_statbuf.st_gid == link_statbuf.st_gid);
    assert(file_statbuf.st_rdev == link_statbuf.st_rdev);
    assert(file_statbuf.st_size == link_statbuf.st_size);
    assert(file_statbuf.st_blksize == link_statbuf.st_blksize);
    assert(file_statbuf.st_blocks == link_statbuf.st_blocks);
    // NB: `atim` is explicitly not compared here
    assert(file_statbuf.st_mtim.tv_sec == link_statbuf.st_mtim.tv_sec);
    assert(file_statbuf.st_mtim.tv_nsec == link_statbuf.st_mtim.tv_nsec);
    assert(file_statbuf.st_ctim.tv_sec == link_statbuf.st_ctim.tv_sec);
    assert(file_statbuf.st_ctim.tv_nsec == link_statbuf.st_ctim.tv_nsec);

    // Test lstat.

    n = lstat(filename, &file_statbuf);
    assert(n == 0);
    assert(file_statbuf.st_size == 0);
    assert(S_ISREG(file_statbuf.st_mode));

    n = lstat(linkname, &link_statbuf);
    assert(n == 0);
    assert(link_statbuf.st_size != 0);
    assert(S_ISLNK(link_statbuf.st_mode));

    assert(file_statbuf.st_dev == link_statbuf.st_dev);
    assert(link_statbuf.st_ino != file_statbuf.st_ino);

    n = unlink(filename);
    assert(n == 0);
    n = unlink(linkname);
    assert(n == 0);

    free(filename);
    free(linkname);

    return 0;
}
