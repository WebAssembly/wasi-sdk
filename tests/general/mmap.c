#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <limits.h>
#include <sys/mman.h>
#include <sys/stat.h>
#ifdef __GLIBC__
#include <sys/user.h>
#endif
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
  char *filename;
  if (asprintf(&filename, "%s/input.txt", argv[1]) == -1) {
    fprintf(stderr, "can't allocate filename");
    return EXIT_FAILURE;
  }

  int fd = open(filename, O_RDONLY);
  if (fd < 0)
    perror_and_exit("open");

  struct stat stat_buf;
  if (fstat(fd, &stat_buf) != 0)
    perror_and_exit("fstat");

  off_t offset = OFFSET;
  if (offset < 0) {
    fprintf(stderr, "negative offset\n");
    return EXIT_FAILURE;
  }
  if (offset > (off_t)SIZE_MAX) {
    fprintf(stderr, "offset overflow\n");
    return EXIT_FAILURE;
  }

  off_t aligned_offset = offset & -(off_t)PAGE_SIZE;

  if (offset >= stat_buf.st_size) {
    fprintf(stderr, "offset is past end of file\n");
    return EXIT_FAILURE;
  }

  size_t length = LENGTH;
  if ((off_t)length < 0) {
    fprintf(stderr, "length overflow\n");
    return EXIT_FAILURE;
  }
  if ((off_t)length > stat_buf.st_size - offset)
    length = (size_t)(stat_buf.st_size - offset);

  size_t mmap_length = length + (size_t)(offset - aligned_offset);
  char *addr = mmap(NULL, mmap_length, PROT_READ, MAP_PRIVATE, fd, aligned_offset);
  if (addr == MAP_FAILED)
    perror_and_exit("mmap");

  ssize_t nwritten = write(STDOUT_FILENO, addr + (offset - aligned_offset), length);
  if (nwritten < 0)
    perror_and_exit("write");

  if ((size_t)nwritten != length) {
    fprintf(stderr, "partial write");
    return EXIT_FAILURE;
  }

  if (munmap(addr, mmap_length) != 0)
    perror_and_exit("munmap");

  if (close(fd) != 0)
    perror_and_exit("close");

  return EXIT_SUCCESS;
}
