#include <stdio.h>

volatile long double x = 42.0L;

int main(void) {
    printf("the answer is %Lf\n", x);
    return 0;
}
