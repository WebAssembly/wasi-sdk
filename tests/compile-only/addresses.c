#include <stdio.h>
#include <limits.h>

extern void __dso_handle;
extern void __data_end;
extern void __global_base;
extern void __heap_base;

int main(int argc, char *argv[]) {
    printf("NULL=%p\n", NULL);
    printf("__dso_handle=%p\n", &__dso_handle);
    printf("__data_end=%p\n", &__data_end);
    printf("__global_base=%p\n", &__global_base);
    printf("__heap_base=%p\n", &__heap_base);
    printf("__builtin_frame_address(0)=%p\n", __builtin_frame_address(0));
    printf("__builtin_alloca(0)=%p\n", __builtin_alloca(0));
    printf("__builtin_wasm_memory_size(0)=%p\n", (void *)(__builtin_wasm_memory_size(0) * PAGE_SIZE));
    return 0;
}
