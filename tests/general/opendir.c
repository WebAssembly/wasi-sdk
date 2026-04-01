#include <fcntl.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <sys/stat.h>
#include <unistd.h>

#define perror_and_exit(message) \
  do {                           \
    perror(message);             \
    return EXIT_FAILURE;         \
  } while (0)

#define OFFSET 10726
#define LENGTH 143

int main(int argc, char *argv[]) {
  if (argc != 2) {
    fprintf(stderr, "usage: %s <dir>\n", argv[0]);
    return EXIT_FAILURE;
  }
  DIR *dir = opendir(argv[1]);
  if (dir == NULL) {
    perror_and_exit("opendir");
  }

  int count = 0;
  int zeros = 0;
  errno = 0;
  for (;; count += 1) {
    struct dirent *ent = readdir(dir);
    if (ent == NULL) {
      if (errno == 0) {
        break;
      }
      perror_and_exit("readdir");
    }

    if (strcmp(ent->d_name, "file.md") == 0) {
      assert(ent->d_type == DT_REG);
    } else if (strcmp(ent->d_name, "dir") == 0) {
      assert(ent->d_type == DT_DIR);
    } else if (strcmp(ent->d_name, "file-symlink") == 0) {
      assert(ent->d_type == DT_LNK);
    } else if (strcmp(ent->d_name, "dir-symlink") == 0) {
      assert(ent->d_type == DT_LNK);
    } else if (strcmp(ent->d_name, ".") == 0) {
      assert(ent->d_type == DT_DIR);
    } else if (strcmp(ent->d_name, "..") == 0) {
      assert(ent->d_type == DT_DIR);
    } else {
      assert(false);
    }
    if (ent->d_ino == 0) {
      zeros += 1;
    }
  }

  assert(count == 6);
  assert(zeros <= 1);

  if (closedir(dir) != 0)
    perror_and_exit("closedir");

  return EXIT_SUCCESS;
}
