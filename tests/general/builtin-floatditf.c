// Primarily check that `libclang_rt.builtins-wasm32.a` functions are present
// and work as expected on all tested targets, not the builtin functionality.

#include <assert.h>

int main() {
  tf_float f = __floatditf(0);
  assert(f == 0.0);
  return 0;
}
