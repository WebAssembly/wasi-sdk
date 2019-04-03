#/bin/bash
LLVM_PROJ_DIR=${1:-./src/llvm-project}
MAJOR=`grep "set(LLVM_VERSION_MAJOR" $LLVM_PROJ_DIR/llvm/CMakeLists.txt | awk '{print substr($2, 1, length($2) - 1)}'`
MINOR=`grep "set(LLVM_VERSION_MINOR" $LLVM_PROJ_DIR/llvm/CMakeLists.txt | awk '{print substr($2, 1, length($2) - 1)}'`
PATCH=`grep "set(LLVM_VERSION_PATCH" $LLVM_PROJ_DIR/llvm/CMakeLists.txt | awk '{print substr($2, 1, length($2) - 1)}'`
echo $MAJOR.$MINOR.$PATCH
