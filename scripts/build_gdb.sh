#!/bin/sh

OS=`uname -s`
MACHINE=`uname -m`

if [ ${OS} = "FreeBSD" ] ; then
    OS_ID=`uname -r | sed -e 's/[-_].*//' | sed -e 's/\..*// '`
    cpus=`sysctl hw.ncpu|sed s/hw.ncpu:\ //g`
    PARALLELISM=$(($cpus * 3/2))
    MAKE=gmake
elif [ $OS = "Linux" ]; then
    OS_ID=`cat /etc/os-release | grep VERSION_ID | awk -F \" '{ print $2 }'`
    OS_ID="Ubuntu-${OS_ID}"
    cpus=`cat /proc/cpuinfo | grep '^processor' | wc -l`
    PARALLELISM=$(($cpus * 3/2))
    MAKE=make
else
    echo "Error: Platform not supported"
    exit 1
fi

HOST_TRIPLE=`clang -dumpmachine`
GDB_REPO="https://github.com/syrajendra/binutils-gdb.git"
GDB_BRANCH="gdb-12-branch"
PRETTY_PRINTER_REPO="https://github.com/syrajendra/libcxx-pretty-printers.git"
GDB_PUBLISH_DATE=`date "+%Y%m%d"`

SUPPORTED_ARCHS="
arm-fbsd
arm64-fbsd
amd64-fbsd
i386-fbsd
mips64-fbsd
mips-fbsd
native
ppc-linux
ppc64-linux
x86_64-linux
i686-linux
i586-linux
i486-linux
i386-linux
arm64-linux
armhf-linux
riscv64-linux
riscv32-linux
"

RUN_NATIVE_TESTS=0      # when set gdb tests are executed for native gdb
DEBUGGABLE=1            # when set gdb is built with debug info

export CC=`which gcc`
export CXX=`which g++`

GCC_VERSION=`$CC -v 2>&1 | grep 'gcc version' | awk '{print $3}'`
BUILT_WITH="gcc-${GCC_VERSION}"

usage()
{
    echo "Usage:
    In the src/ directory:
    ./${0##*/} \$arch...
    Attempt to build & install the gdb & kgdb for each of arch given
    supported arches are:
    $(echo $SUPPORTED_ARCHS)
    if 'all' is specified for supported arches then all of the supported
    architectures are built

    examples:
        ./`basename $0` amd64-fbsd
        ./`basename $0` all
        ./`basename $0` arm-fbsd i386-fbsd x86_64-linux
    "
}

while getopts 's:t:' OPTION
    do
        case $OPTION in
        s)
            sysroot_path=$OPTARG
            ;;
        t)
            custom_target=$OPTARG
            ;;
        ?)
            usage
    esac
done

archs="$*"

# build all
if test "x$archs" = "xall"; then
    archs="$SUPPORTED_ARCHS"
fi

if test "x$archs" = "x"; then
    echo "Error: no architecture specified to build -- nothing to do."
    usage
    exit 1
fi

org_path="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:"

top=`cd $PWD/../../ && pwd -P | tr '\n' ' ' | xargs`
gdbdir=$top/binutils-gdb

gserver_flag=""

if [ $DEBUGGABLE = 1 ]; then
    make_flags="$make_flags CFLAGS='-O0 -g' CXXFLAGS='-O0 -g'"
    debug_dir="-debug"
fi

for arch in $archs; do
    if [ x${custom_target} = x ]; then
        case $arch in
            native)
                target=
                install_target=${HOST_TRIPLE}
                exeprefix=""
                gdb_config_flags="--enable-64-bit-bfd"
                ;;
            arm-fbsd)
                target=armv7-unknown-freebsd-gnueabi
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
            ;;
            armhf-fbsd)
                target=armv7-unknown-freebsd-gnueabihf
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            arm64-fbsd)
                target=aarch64-unknown-freebsd
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            amd64-fbsd|x86_64-fbsd)
                target=amd64-unknown-freebsd
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            i386-fbsd)
                target=i386-unknown-freebsd
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            ppc64-fbsd|powerpc64)
                target=powerpc64-unknown-freebsd
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            ppc-fbsd|powerpc-fbsd)
                target=powerpc-unknown-freebsd
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            mips64-fbsd)
                target=mips64-unknown-freebsd
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            mips-fbsd)
                target=mips-unknown-freebsd
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            ppc-linux)
                target=powerpc-unknown-linux-gnu
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            ppc64-linux)
                target=powerpc64-unknown-linux-gnu
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            x86_64-linux)
                target=x86_64-unknown-linux-gnu
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            i686-linux)
                target=i686-unknown-linux-gnu
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            i586-linux)
                target=i586-unknown-linux-gnu
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            i486-linux)
                target=i486-unknown-linux-gnu
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            i386-linux)
                target=i386-unknown-linux-gnu
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            arm64-linux)
                target=aarch64-unknown-linux-gnu
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            armhf-linux)
                target=arm-unknown-linux-gnueabihf
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            riscv64-linux)
                target=riscv64-unknown-linux-gnu
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            riscv32-linux)
                target=riscv32-unknown-linux-gnu
                install_target=$target
                exeprefix="$target-"
                gdb_config_flags=""
                ;;
            *)
            echo "Error: Architecture \"${arch}\" not supported"
            usage
            exit 1
            ;;
        esac

        if test x$target != x; then
            gdb_config_flags="
                --target=$target
                $gdb_config_flags
                "
        fi
        objbase=$top/gdb-build${debug_dir}/${BUILT_WITH}/$OS/$OS_ID/$MACHINE/$arch
    else

        # Custom target
        target=${custom_target}
        install_target=$target
        exeprefix="$target-"
        gdb_config_flags="--target=${target}"

        # Check for sysroot
        if test x$sysroot_path != x; then
            gdb_config_flags="
                --with-sysroot=$sysroot_path
                $gdb_config_flags
                "
        fi
        objbase=$top/gdb-build${debug_dir}/${BUILT_WITH}/$OS/$OS_ID/$MACHINE/$custom_target
    fi

    if test x$target != x; then
        case $target in
            *linux*) target_os=Linux;;
            *freebsd*) target_os=FreeBSD;;
            *) echo "Failed to detect target"; exit 1;;
        esac
        make_flags="$make_flags CFLAGS='-DTARGET_OS=$target_os' CXXFLAGS='-DTARGET_OS=$target_os'"
    fi

    if [ x$arch != xppc-fbsd ] && [ x$arch != xpowerpc-fbsd ]; then
        echo "+-----------------------------------------------+"
        echo "| Building ${exeprefix}gdb |"
        echo "+-----------------------------------------------+"

        
        local_install=$top/gdb-install${debug_dir}/${BUILT_WITH}/$OS/$OS_ID/$MACHINE
        prefix=${local_install}/gdb/${GDB_PUBLISH_DATE}
        
        mkdir -p ${objbase}
        cd ${objbase}
        if [ ! -e .configured ]; then
            cfg="
            --prefix=${prefix}
            --disable-werror
            --disable-nls
            --disable-binutils
            --disable-gprof
            --disable-gas
            --disable-ld
            --disable-gold
            --disable-gdbtk
            --enable-gcore
            --enable-tui
            --enable-sim
            --with-x=no
            --with-lzma=no
            ${gdb_config_flags}
            ${gserver_flag}
            "
            echo "gdb configured with ..."
            echo $make_flags ${gdbdir}/configure $cfg
            eval $make_flags \
            ${gdbdir}/configure \
            $cfg \
            && touch .configured
        fi

        if [ ! -e .compiled ]; then
            $MAKE V=1 -j$PARALLELISM all-gdb all-sim 2>&1 | tee  build-gdb.log && touch .compiled
        else
            echo "Compiled  @ $PWD"
        fi

        if [ ! -e .installed ]; then
            $MAKE install-gdb install-sim && touch .installed
        else
            echo "Installed @ ${prefix}"
        fi

        if [ "$?" -ne 0 ];then
            echo "Error while building gdb"
            exit 1
        fi

        # Remove unnecessary stuff
        rm -rf ${prefix}/include ${prefix}/lib

        # for baseline builds generate test results as well
        if [ $RUN_NATIVE_TESTS = 1 ] && [ $arch = "native" ]; then
            cd gdb
            $MAKE check
            # for single test run
            #$make check RUNTESTFLAGS="mytest.exp"
        fi
    fi
done
