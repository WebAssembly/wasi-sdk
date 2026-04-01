#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
extern char **environ;

int main(void) {
    assert(environ != NULL);
    for (char **p = environ; *p; ++p) {
        assert(p != NULL);
    }
    for (char **p = environ; *p; ++p) {
        if (strncmp(*p, "HELLO=", 5) == 0) {
            printf("HELLO = %s\n", *p + 6);
        }
    }
    return 0;
}
