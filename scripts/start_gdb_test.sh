#!/bin/sh

OUTPUT=`cat /proc/sys/kernel/yama/ptrace_scope`
if [ "$OUTPUT" != "0" ]; then
    echo "Kernel disabled ptrace attach by default. Run below commands"
    echo "sudo su -"
    echo "echo 0 > /proc/sys/kernel/yama/ptrace_scope"
    exit 1
fi

# Due to kernel hardening in Linux ptrace attach is disabled by default
# Before running any GDB tests run below command on Ubuntu
# sudo su -
# echo 0 > /proc/sys/kernel/yama/ptrace_scope

TOP=`realpath $(dirname $0)/../../`
export BOARDS_DIR=`realpath $(dirname $0)/../boards`
OS=`uname -s`
MACHINE=`uname -m`

# default gdb source location
export GDB_SRC=${GDB_SRC:-$TOP/binutils-gdb}
# default gdb binary
export GDB_EXE=${GDB_EXE:-/usr/bin/gdb}
# default pretty printer
export PRETTY_PRINTER=${PRETTY_PRINTER:-$TOP/libcxx-pretty-printers/src/gdbinit}
# default deebe path on remote machine
export DEEBE_PATH="/usr/local/bin/deebe"
# default sysroot
export SYSROOT=${SYSROOT:-$TOP/sysroot}

if [ $# != 1 ] && [ $# != 2 ]; then
    echo "ERROR: Supply arguments"
    echo "Supply argument <board-name>/native-gcc/native-clang. Optional argument GDB <testcase>"
    exit 1
else
    export BOARD=$1
    EXP=$2
fi

# verify gdb src path
if [ x$GDB_SRC = x ] || [ ! -d $GDB_SRC ]; then
    echo "ERROR: GDB_SRC path is wrong '$GDB_SRC'"
    exit 1
else
    if [ ! -d $GDB_SRC/gdb/testsuite ]; then
        echo "ERROR: GDB source path '$GDB_SRC' is wrong"
        exit 1
    else
        export GDB_TEST_DIR=$GDB_SRC/gdb/testsuite
        if [ ! -d $GDB_TEST_DIR ]; then
            echo "ERROR: GDB_SRC path is wrong $GDB_SRC"
            exit 1
        fi
        echo "GDB test dir : $GDB_TEST_DIR"
    fi
fi

# verify gdb path
GDB_VERSION=`$GDB_EXE -v | head -n 1 | awk '{print $5}' | xargs`
if [ x$GDB_VERSION = x ]; then
    GDB_VERSION=`$GDB_EXE -v | head -n 1 | awk '{print $4}' | xargs`
fi
echo "Gdb version : $GDB_VERSION"

GDB_MAJOR_VER=`echo $GDB_VERSION | tr "." " " | awk '{print $1}' | xargs`
if [ "$GDB_MAJOR_VER" = "7" ]; then
    GDB_CONFIG_LINE=`$GDB_EXE -v | grep "This GDB was configured as"`
else
    GDB_CONFIG_LINE=`$GDB_EXE --configuration | grep "configure "`
    mhost=`echo $GDB_CONFIG_LINE | awk '{print $2}' | sed s/.*=//g | xargs`
    mtarget=`echo $GDB_CONFIG_LINE | awk '{print $3}' | sed s/.*=//g | xargs`
    if [ $mhost = $mtarget ]; then
        GDB_CONFIG_LINE="configure --host=$mhost"
    fi
fi

# verify pretty printer path
if [ ! -f $PRETTY_PRINTER ]; then
    echo "ERROR: Failed to locate pretty printer path"
    exit 1
fi

if [ $OS = "FreeBSD" ]; then
    HOST_CC=clang
    HOST_CXX=clang++
elif [ $OS = "Linux" ]; then
    HOST_CC=gcc
    HOST_CXX=g++
else
    echo "ERROR: Platform not supported"
    exit 1
fi

if [ $BOARD != "native-clang" ] && [ $BOARD != "native-gcc" ]; then
    # cross gdb testing
    export BOARD_OS=`ssh $BOARD uname -s`
    if [ "$BOARD_OS" = "FreeBSD" ]; then
        export BOARD_CC=clang
        export BOARD_CXX=clang++
    elif [ "$BOARD_OS" = "Linux" ]; then
        export BOARD_CC=gcc
        export BOARD_CXX=g++
    else
        echo "ERROR: Board os not supported"
        exit 1
    fi
    echo "Board os : $BOARD_OS"

    export BOARD_TRIPLE=`ssh $BOARD ${BOARD_CC} -dumpmachine`
    echo "Board triple : $BOARD_TRIPLE"

    if [ ! -d $SYSROOT/$BOARD_TRIPLE ]; then
        echo "ERROR: Failed to find sysroot $SYSROOT/$BOARD_TRIPLE"
        exit 1
    else
        export SYSROOT_PATH=$SYSROOT/$BOARD_TRIPLE
    fi

    export BOARD_ARCH=`echo $BOARD_TRIPLE | sed s/-.*//g`
    echo "Board architecture : $BOARD_ARCH"
    
    if echo $GDB_CONFIG_LINE | grep -q 'target='; then # cross gdb testing
        if [ "$GDB_MAJOR_VER" = "8" ] || [ "$GDB_MAJOR_VER" = "9" ]; then
            GDB_TARGET=`echo $GDB_CONFIG_LINE | awk '{print $3}' | sed s/--target=//g`
        else
            GDB_TARGET=`echo $GDB_CONFIG_LINE | awk '{print $7}' | sed s/\"\.//g | sed s/--target=//g`
        fi
        if echo $GDB_TARGET | grep -q $BOARD_ARCH; then
            echo "GDB target : $GDB_TARGET"
        else
            if [ $BOARD_ARCH = "x86_64" ]; then
                if echo $GDB_TARGET | grep -q amd64; then
                    echo "GDB target : $GDB_TARGET"
                fi
            else
                echo "ERROR: Board $BOARD architecture is '$BOARD_ARCH' and GDB executable target is '$GDB_TARGET' does not match"
                exit 1
            fi
        fi
    else
        echo "ERROR: Not cross gdb in GDB_EXE"
        exit 1
    fi
        
    export CC=`which ${BOARD_TRIPLE}-clang`
    if [ x$CC = x ]; then
        export CC=`which ${BOARD_TRIPLE}-gcc`
        if [ x$CC = x ]; then
            echo "ERROR: No c cross compiler found for ${BOARD_TRIPLE}"
            exit 1
        fi
    fi
    export CXX=`which ${BOARD_TRIPLE}-clang++`
    if [ x$CXX = x ]; then
        export CXX=`which ${BOARD_TRIPLE}-g++`
        if [ x$CXX = x ]; then
            echo "ERROR: No c++ cross compiler found for ${BOARD_TRIPLE}"
            exit 1
        fi
    fi

    export BOARD_TARGET=$BOARD_TRIPLE
    export COMPILER_CC=${CC}
    export COMPILER_CXX=${CXX}
    export BOARD_NAME=$BOARD
else
    # host testing
    ulimit -c unlimited
    export BOARD_TARGET=native
    if [ $BOARD = "native-gcc" ]; then
        export COMPILER_CC=gcc
        export COMPILER_CXX=g++
    elif [ $BOARD = "native-clang" ]; then
        export COMPILER_CC=clang
        export COMPILER_CXX=clang++
    else
        echo "ERROR: Native supports native-clang/native-gcc only"
        exit 1
    fi
fi

export LDFLAGS=""
export CC=$COMPILER_CC
export CXX=$COMPILER_CXX

export PATH=`dirname $GDB_EXE`:$PATH

export BOARD_GDB=$GDB_EXE
if `echo $COMPILER_CC | grep -q gcc` ; then
	export COMPILER_TYPE=gcc
    export BOARD_LD=ld
else
	export COMPILER_TYPE=clang
    export BOARD_LD=lld
fi

CC_VERSION=`${COMPILER_CC} --version`
if [ $? != 0 ]; then
    echo "Could not find the boards compiler : $COMPILER_CC"
    exit 1
else
    echo "${COMPILER_CC} version $CC_VERSION"
fi

export DEJAGNU=$BOARDS_DIR/my_dejagnu.exp

TOOL=gdb

RUN_DIR=$PWD/results
if [ ! -d $RUN_DIR ]; then
    mkdir -p $RUN_DIR
fi

DEJADIR=$RUN_DIR

if [ ! -d ${RUN_DIR}/config ]; then
    mkdir -p ${RUN_DIR}/config
fi
CONFIG=${RUN_DIR}/config/base-config.exp

OBJ_DIR=$DEJADIR/rundir/$USERNAME/${BOARD}/${BOARD_TARGET}/gdb/
if [ ! -d $OBJ_DIR ]; then
    mkdir -p $OBJ_DIR
fi

remote_path="/tmp/$USERNAME/${BOARD}/$BOARD_TARGET/dejagnu/gdb/"
if [ $BOARD_TARGET != native ]; then
    ssh ${BOARD} "mkdir -p $remote_path"
fi
TMP_DIR=$remote_path
mkdir -p $TMP_DIR
SITE=${OBJ_DIR}/site.exp

echo "# Generated file"                > $CONFIG
echo "set tool $TOOL"                  > $SITE
echo "set srcdir $GDB_TEST_DIR"       >> $SITE
echo "set objdir $OBJ_DIR"            >> $SITE
echo "set tmpdir $TMP_DIR"            >> $SITE
export REMOTE_TMP_PATH=$remote_path

echo "set INTERNAL_GDBFLAGS \"-nw -nx\"" >> $SITE

if [ ! -d $OBJ_DIR/boards ]; then
    mkdir -p $OBJ_DIR/boards
fi

cd $OBJ_DIR

#VERBOSE="-v -v -v -v -v -v -debug"
if [ $BOARD = "native-gcc" ] || [ $BOARD = "native-clang" ]; then
    ln -sf $BOARDS_DIR/generic_board.exp $BOARDS_DIR/unix.exp
    runtest -a $VERBOSE --tool $TOOL --target_board unix $EXP
else
    ln -sf $BOARDS_DIR/generic_board.exp $BOARDS_DIR/$BOARD.exp
    runtest -a $VERBOSE --tool $TOOL --target_board $BOARD $EXP
fi

# GDB_PARALLEL=yes FORCE_PARALLEL=4 FORCE_SEPARATE_MI_TTY=1 


