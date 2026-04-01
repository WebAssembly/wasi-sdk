#include <stdio.h>

volatile int x = 42;

int main(void) {
    printf("the answer is %d\n", x);
    return 0;
}
