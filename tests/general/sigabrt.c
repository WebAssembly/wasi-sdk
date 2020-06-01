#include <signal.h>
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    fprintf("raising SIGABRT...\n");
    raise(SIGABRT);
    fprintf("oops!\n");
    return EXIT_FAILURE;
}
