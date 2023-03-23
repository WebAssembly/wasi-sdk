#/bin/bash
LLVM_PROJ_DIR=${1:-./src/llvm-project}
MAJOR=`grep "set(LLVM_VERSION_MAJOR" $LLVM_PROJ_DIR/llvm/CMakeLists.txt | awk '{print substr($2, 1, length($2) - 1)}'`
echo $MAJOR
