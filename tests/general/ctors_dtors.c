#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <errno.h>
extern char **environ;

static void from_atexit(void) {
    printf("hello from_atexit\n");
}

static void another_from_atexit(void) {
    printf("hello another_from_atexit\n");
}

__attribute__((constructor)) static void from_constructor(void) {
    printf("hello from_constructor\n");
}

__attribute__((constructor(101))) static void from_constructor_101(void) {
    assert(errno == 0);
    printf("hello from_constructor101\n");

    assert(environ && "environment should be initialized by this point");
}

__attribute__((constructor(65535))) static void from_constructor_65535(void) {
    printf("hello from_constructor65535\n");
}

__attribute__((destructor)) static void from_destructor(void) {
    printf("hello from_destructor\n");
}

__attribute__((destructor(101))) static void from_destructor101(void) {
    printf("hello from_destructor101\n");
}

__attribute__((destructor(65535))) static void from_destructor65535(void) {
    printf("hello from_destructor65535\n");
}

int main(int argc, char *argv[]) {
    printf("hello main\n");
    assert(argc != 0);
    assert(argv != NULL);
    assert(argv[argc] == NULL);

    atexit(from_atexit);
    atexit(another_from_atexit);
    printf("goodbye main\n");
    return 0;
}
