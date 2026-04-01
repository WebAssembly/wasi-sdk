#include <assert.h>
#include <unistd.h>
#include <stdbool.h>

int main() {
  char buf[256] = {0};
  int ret = getentropy(buf, 256);
  assert(ret == 0);

  bool something_nonzero = false;
  for (int i = 0; i < 256; i++) {
    if (buf[i] != 0)
      something_nonzero = true;
  }

  assert(something_nonzero);

  return 0;
}
