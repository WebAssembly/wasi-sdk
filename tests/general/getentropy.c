#include <assert.h>
#include <unistd.h>

int main() {
  char buf[256] = {0};
  int ret = getentropy(buf, 256);
  assert(ret == 0);

  int sum = 0;
  for (int i = 0; i < 256; i++) {
    sum += buf[i];
  }

  assert(sum != 0);

  return 0;
}
