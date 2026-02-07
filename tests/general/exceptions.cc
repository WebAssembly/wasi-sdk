#include <iostream>

int main() {
#ifdef __wasm_exception_handling__
  try {
    throw std::runtime_error("An error occurred");
  } catch (const std::runtime_error& e) {
    // ..
  }
#endif
  return 0;
}
