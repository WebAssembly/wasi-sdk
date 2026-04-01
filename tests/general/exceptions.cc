#include <iostream>
#include <stdlib.h>

int main() {
#ifdef __wasm_exception_handling__
  try {
    throw std::runtime_error("An error occurred");
    abort();
  } catch (const std::runtime_error& e) {
    // ..
    return 0;
  }
  abort();
#else
  return 0;
#endif
}
