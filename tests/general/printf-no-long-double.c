#include <stdio.h>

volatile double x = 42.0;

int main(void) {
    printf("the answer is %f\n", x);
    return 0;
}
