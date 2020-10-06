#!/bin/sh

OS=`uname -s`
MACHINE=`uname -m`

DEEBE_REPO="https://github.com/syrajendra/deebe.git"
TOP=`cd $PWD/../../ && pwd -P | tr '\n' ' ' | xargs`

SRC=$TOP/deebe

if [ ! -d $SRC ]; then
    echo "Failed to find deebe source at $SRC"
    exit 1
fi

mkdir -p $TOP/deebe-build $TOP/deebe-install
cd $TOP/deebe-build
$SRC/configure --prefix=$TOP/deebe-install
make -j4
make install
