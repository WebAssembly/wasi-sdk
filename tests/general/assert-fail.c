#ifdef NDEBUG
#undef NDEBUG
#endif

#include <assert.h>
#include <stdbool.h>

int main(void) {
    assert(false);
    return 0;
}
