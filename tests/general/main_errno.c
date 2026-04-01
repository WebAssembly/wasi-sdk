#include <stdio.h>
#include <errno.h>
#include <string.h>

// It isn't required that errno be zero on entry to main, but
// for tidiness' sake, if we ever do things during startup that
// do set errno, we should reset it for tidiness' sake.
int main(void) {
    int n = errno;
    printf("initial errno is %d: %s\n", n, strerror(n));
    return 0;
}
