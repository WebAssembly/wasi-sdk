#include <stdio.h>
#include <limits.h>
#include <errno.h>
extern char **environ;

extern void __dso_handle;
#if !defined(__clang_major__) || __clang_major__ >= 10
extern void __data_end;
extern void __global_base;
extern void __heap_base;
#endif

int main(int argc, char *argv[]) {
    printf("NULL=%p\n", NULL);
    printf("__dso_handle=%p\n", &__dso_handle);
#if !defined(__clang_major__) || __clang_major__ >= 10
    printf("__data_end=%p\n", &__data_end);
    printf("__global_base=%p\n", &__global_base);
    printf("__heap_base=%p\n", &__heap_base);
#endif
    printf("__builtin_frame_address(0)=%p\n", __builtin_frame_address(0));
    printf("__builtin_alloca(0)=%p\n", __builtin_alloca(0));
    printf("__builtin_wasm_memory_size(0)=%p\n", (void *)(__builtin_wasm_memory_size(0) * PAGE_SIZE));
    printf("&errno=%p\n", (void *)&errno);
    printf("&environ=%p\n", (void *)&environ);
    return 0;
}
