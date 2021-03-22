#include <time.h>
#include <sys/resource.h>
#include <sys/times.h>
#include <assert.h>

static void test_clock(void) {
    clock_t a = clock();
    clock_t b = clock();
    assert(a != -1);
    assert(b != -1);
    assert(a > 0);
    assert(b >= a);
}

static void test_times(void) {
    struct tms before;
    struct tms after;
    clock_t a = times(&before);
    clock_t b = times(&after);
    assert(a != -1);
    assert(b != -1);
    assert(b >= a);
    assert(after.tms_utime >= before.tms_utime);
}

static void test_getrusage(void) {
    struct rusage before;
    struct rusage after;
    int a = getrusage(RUSAGE_SELF, &before);
    int b = getrusage(RUSAGE_SELF, &after);
    assert(a != -1);
    assert(b != -1);
    assert(after.ru_utime.tv_sec >= before.ru_utime.tv_sec);
    assert(after.ru_utime.tv_sec != before.ru_utime.tv_sec ||
	   after.ru_utime.tv_usec >= before.ru_utime.tv_usec);
}

int main(void) {
    test_clock();
    test_times();
    test_getrusage();
    return 0;
}
