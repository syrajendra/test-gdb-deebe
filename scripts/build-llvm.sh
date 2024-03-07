#!/bin/sh

OS=`uname -s`
OS_ID=`/volume/hab/${OS}/bin/os-id`
MACHINE=`uname -m`
TOP=$PWD
TODAY=`date +%Y%m%d`
BUILD=$TOP/build/$TODAY
rm -rf $BUILD
mkdir -p $BUILD

cmake -S $TOP/llvm-project/llvm -B $BUILD \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS=all \
	-DLLVM_ENABLE_RUNTIMES=all \
	-DLLVM_TARGETS_TO_BUILD=all \
	-DLLVM_ENABLE_RTTI=True \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_C_COMPILER=clang \
	-DLLVM_USE_LINKER=lld \
	-DLLVM_PARALLEL_LINK_JOBS=1 \
	-DLLVM_PARALLEL_COMPILE_JOBS=4 \
	-DCLANG_DEFAULT_CXX_STDLIB=libc++ \
	-DSANITIZER_CXX_ABI=libc++ \
	-DLLVM_ENABLE_Z3_SOLVER=OFF

cmake --build $BUILD -j4
cmake --install $BUILD --prefix /volume/hab/$OS/$OS_ID/$MACHINE/llvm/main/$TODAY

