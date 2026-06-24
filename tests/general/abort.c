#include <stdlib.h>
void __wasm_set_tls_base(void *base);
int main(void) {
    __wasm_set_tls_base(NULL);
    abort();
    return 0;
}
