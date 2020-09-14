#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include <assert.h>
#include <sys/stat.h>

int main() {
    DIR *dirp = opendir("readdir.c.dir");
    assert(dirp);

    struct dirent *entry;

    bool saw_dot = false;
    bool saw_dotdot = false;
    bool saw_input_txt = false;

    ino_t dot_ino = 0;
    ino_t input_txt_ino = 0;

    off_t start_off = telldir(dirp);
    off_t last_off = start_off;
    off_t dot_off = 0;
    off_t dotdot_off = 0;
    off_t input_txt_off = 0;

    while ((entry = readdir(dirp)) != NULL) {
	last_off = telldir(dirp);
	assert(last_off != start_off);

        if (strcmp(entry->d_name, ".") == 0) {
            assert(!saw_dot);
            saw_dot = true;
            dot_ino = entry->d_ino;
            dot_off = last_off;
            assert(entry->d_type == DT_DIR);
        } else if (strcmp(entry->d_name, "..") == 0) {
            assert(!saw_dotdot);
            saw_dotdot = true;
            dotdot_off = last_off;
            assert(entry->d_type == DT_DIR);
        } else if (strcmp(entry->d_name, "input.txt") == 0) {
            assert(!saw_input_txt);
            saw_input_txt = true;
            input_txt_ino = entry->d_ino;
            input_txt_off = last_off;
            assert(entry->d_type == DT_REG);
        } else {
            assert(false);
        }
    }
    assert(saw_dot);
    assert(saw_dotdot);
    assert(saw_input_txt);

    struct stat statbuf;
    assert(stat("readdir.c.dir", &statbuf) == 0);
    assert(statbuf.st_ino == dot_ino);
    assert(stat("readdir.c.dir/input.txt", &statbuf) == 0);
    assert(statbuf.st_ino == input_txt_ino);

    // Seek back to the start.
    seekdir(dirp, start_off);
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
    seekdir(dirp, dot_off);
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
    seekdir(dirp, dotdot_off);
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
    seekdir(dirp, input_txt_off);
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
    seekdir(dirp, start_off);
    seekdir(dirp, last_off);
    assert(readdir(dirp) == NULL);

    int r = closedir(dirp);
    assert(r == 0);

    return EXIT_SUCCESS;
}
