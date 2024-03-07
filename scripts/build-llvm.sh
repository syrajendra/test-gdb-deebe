#!/bin/sh

OS=`uname -s`
OS_ID=`/volume/hab/${OS}/bin/os-id`
MACHINE=`uname -m`
TOP=$PWD
TODAY=`date +%Y%m%d`
BUILD=$TOP/build/$TODAY
cmake -S $TOP/llvm-project/llvm -B $BUILD \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS=all \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_C_COMPILER=clang
cmake --build $BUILD -j4
cmake --install $BUILD --prefix /volume/hab/$OS/$OS_ID/$MACHINE/llvm/main/$TODAY
