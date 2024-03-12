#/bin/bash
LLVM_PROJ_DIR=${1:-./src/llvm-project}
MAJOR=`(grep "set(LLVM_VERSION_MAJOR" $LLVM_PROJ_DIR/llvm/CMakeLists.txt || grep "set(LLVM_VERSION_MAJOR" $LLVM_PROJ_DIR/cmake/Modules/LLVMVersion.cmake) | awk '{print substr($2, 1, length($2) - 1)}'`
echo $MAJOR
