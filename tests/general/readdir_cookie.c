// Like readdir.c, but uses `d_loc` and `__wasilibc_seekdir` instead
// of `telldir` and `seekdir`.

#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include <assert.h>
#include <sys/stat.h>
#include <wasi/libc.h>

int main() {
    DIR *dirp = opendir("readdir_cookie.c.dir");
    assert(dirp);

    struct dirent *entry;

    bool saw_dot = false;
    bool saw_dotdot = false;
    bool saw_input_txt = false;

    ino_t dot_ino = 0;
    ino_t input_txt_ino = 0;

    off_t start_loc = __WASI_DIRCOOKIE_START;
    off_t last_loc = start_loc;
    off_t dot_loc = 0;
    off_t dotdot_loc = 0;
    off_t input_txt_loc = 0;

    while ((entry = readdir(dirp)) != NULL) {
	last_loc = entry->d_loc;
	assert(last_loc != start_loc);

        if (strcmp(entry->d_name, ".") == 0) {
            assert(!saw_dot);
            saw_dot = true;
            dot_ino = entry->d_ino;
            dot_loc = last_loc;
            assert(entry->d_type == DT_DIR);
        } else if (strcmp(entry->d_name, "..") == 0) {
            assert(!saw_dotdot);
            saw_dotdot = true;
            dotdot_loc = last_loc;
            assert(entry->d_type == DT_DIR);
        } else if (strcmp(entry->d_name, "input.txt") == 0) {
            assert(!saw_input_txt);
            saw_input_txt = true;
            input_txt_ino = entry->d_ino;
            input_txt_loc = last_loc;
            assert(entry->d_type == DT_REG);
        } else {
            assert(false);
        }
    }
    assert(saw_dot);
    assert(saw_dotdot);
    assert(saw_input_txt);

    struct stat statbuf;
    assert(stat("readdir_cookie.c.dir", &statbuf) == 0);
    assert(statbuf.st_ino == dot_ino);
    assert(stat("readdir_cookie.c.dir/input.txt", &statbuf) == 0);
    assert(statbuf.st_ino == input_txt_ino);

    // Seek back to the start.
    __wasilibc_seekdir(dirp, start_loc);
    saw_dot = false;
    saw_dotdot = false;
    saw_input_txt = false;
    while ((entry = readdir(dirp)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0) {
            assert(!saw_dot);
            saw_dot = true;
        } else if (strcmp(entry->d_name, "..") == 0) {
            assert(!saw_dotdot);
            saw_dotdot = true;
        } else if (strcmp(entry->d_name, "input.txt") == 0) {
            assert(!saw_input_txt);
            saw_input_txt = true;
        } else {
            assert(false);
        }
    }
    assert(saw_dot);
    assert(saw_dotdot);
    assert(saw_input_txt);

    // Seek back to the dot.
    __wasilibc_seekdir(dirp, dot_loc);
    saw_dot = true;
    saw_dotdot = false;
    saw_input_txt = false;
    while ((entry = readdir(dirp)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0) {
            assert(!saw_dot);
            saw_dot = true;
        } else if (strcmp(entry->d_name, "..") == 0) {
            assert(!saw_dotdot);
            saw_dotdot = true;
        } else if (strcmp(entry->d_name, "input.txt") == 0) {
            assert(!saw_input_txt);
            saw_input_txt = true;
        } else {
            assert(false);
        }
    }

    // Seek back to the dotdot.
    __wasilibc_seekdir(dirp, dotdot_loc);
    saw_dot = false;
    saw_dotdot = true;
    saw_input_txt = false;
    while ((entry = readdir(dirp)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0) {
            assert(!saw_dot);
            saw_dot = true;
        } else if (strcmp(entry->d_name, "..") == 0) {
            assert(!saw_dotdot);
            saw_dotdot = true;
        } else if (strcmp(entry->d_name, "input.txt") == 0) {
            assert(!saw_input_txt);
            saw_input_txt = true;
        } else {
            assert(false);
        }
    }

    // Seek back to the input.txt.
    __wasilibc_seekdir(dirp, input_txt_loc);
    saw_dot = false;
    saw_dotdot = false;
    saw_input_txt = true;
    while ((entry = readdir(dirp)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0) {
            assert(!saw_dot);
            saw_dot = true;
        } else if (strcmp(entry->d_name, "..") == 0) {
            assert(!saw_dotdot);
            saw_dotdot = true;
        } else if (strcmp(entry->d_name, "input.txt") == 0) {
            assert(!saw_input_txt);
            saw_input_txt = true;
        } else {
            assert(false);
        }
    }

    // Seek to the end.
    __wasilibc_seekdir(dirp, start_loc);
    __wasilibc_seekdir(dirp, last_loc);
    assert(readdir(dirp) == NULL);

    int r = closedir(dirp);
    assert(r == 0);

    return EXIT_SUCCESS;
}
