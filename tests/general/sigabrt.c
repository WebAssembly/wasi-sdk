#include <signal.h>
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    fprintf(stderr, "raising SIGABRT...\n");
    raise(SIGABRT);
    fprintf(stderr, "oops!\n");
    return EXIT_FAILURE;
}
