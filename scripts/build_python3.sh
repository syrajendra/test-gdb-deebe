#!/bin/sh
#-----------------------------------------#
# Copyright (c) 2020-2023 by Rajendra S Y #
# All rights reserved.                    #
#-----------------------------------------#
TODAY=`date +%Y%m%d`
OS=`uname`
MACHINE=`uname -m`
OS_ID=`/volume/hab/${OS}/bin/os-id`
PYTHON_BUILD_DIR=$(pwd)
HAB_DIR="/volume/hab"

# Edit below for different versions of python ###
PYTHON_VERSION="3.12.2"
PYTHON_DOWNLOAD_CMD="wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz"
if [ $OS = "Linux" ]; then
	PYTHON_MODULES="pytest"
elif [ $OS = "FreeBSD" ]; then
	if [ $OS_ID = "7" ]; then
		PYTHON_MODULES="pytest"
	else
		PYTHON_MODULES="pytest"
	fi
fi
###########################################################################################

PYTHON_ZIP_FILE=`basename $(echo "$PYTHON_DOWNLOAD_CMD" | sed s/wget\ //g)`
PYTHON_FILE=`echo $PYTHON_ZIP_FILE | sed s/.tar.*//g`
SRC=$PYTHON_BUILD_DIR/python/${PYTHON_VERSION}/src
BUILD=$PYTHON_BUILD_DIR/python/${PYTHON_VERSION}/build/${OS}/${OS_ID}/${MACHINE}
TIMESTAMP=`date +%s`
LOG_FILE=$BUILD/python_${TIMESTAMP}.log
LOG_CMD=" >> $LOG_FILE 2>&1 "
INSTALL=/volume/hab/$OS/$OS_ID/${MACHINE}/python/$PYTHON_VERSION/$TODAY
PUBLISH_DIR=$HAB_DIR/$OS/$OS_ID/${MACHINE}/python/$PYTHON_VERSION/$TODAY

if [ $OS = "Linux" ]; then
	MAKE="make"
	# CPUs = Threads per core X cores per socket X sockets
	CORES_PER_CPU=`cat /proc/cpuinfo | grep -m 1 'cpu cores' | awk '{ print $4 }'`
	TOTAL_CPUS=`cat /proc/cpuinfo | grep processor | wc -l`
	if [ "$CORES_PER_CPU" = "0" ]; then
		CORES_PER_CPU=1
	fi
	CPUS=$(($CORES_PER_CPU * $TOTAL_CPUS))
elif [ $OS = "FreeBSD" ]; then
	MAKE="gmake"
	CPUS=`sysctl hw.ncpu|sed s/hw.ncpu:\ //g`
else
	echo "Platform not supported"
	exit 1
fi

run_cmd() {
	echo "CMD: $@"
	if [ "x$DRY_RUN" = "x" ] || [ "x$DRY_RUN" = "x0" ]; then
		if eval "$@"; then
			echo "Status : Success"
		else
			echo "Status : Failed"
			exit 1
		fi
	else
		echo "Dry run success"
	fi
}

init() {
	run_cmd "mkdir -p $SRC"
	run_cmd "mkdir -p $BUILD"
}

get_src() {
	# Get source
	if [ ! -f $SRC/$PYTHON_ZIP_FILE ]; then
		run_cmd "cd $SRC && $PYTHON_DOWNLOAD_CMD $LOG_CMD"
	fi

	cmd="cd $SRC && tar -xpvf $PYTHON_ZIP_FILE"
	if [ ! -d $SRC/$PYTHON_FILE ]; then
		run_cmd "$cmd $LOG_CMD"
	fi
}


build_install() {
	# Build
	cmd="cd $BUILD && $SRC/$PYTHON_FILE/configure --enable-shared  --with-zlib=/usr/include --prefix=$INSTALL LDFLAGS=\"-Wl,-rpath='\\\$\\\$ORIGIN/../lib' -Wl,-z,origin\" --enable-unicode=ucs4"
	run_cmd "$cmd $LOG_CMD"

	cmd="cd $BUILD && $MAKE -j $CPUS"
	run_cmd "$cmd $LOG_CMD"
	run_cmd "mkdir -p $INSTALL"
	cmd="cd $BUILD && $MAKE install"
	run_cmd "$cmd $LOG_CMD"
	echo "Successfully installed python-$PYTHON_VERSION"
}

install_modules() {
  # upgrade pip3
  $INSTALL/bin/python3 -m pip install --upgrade pip
	# Install modules
	PIP=$INSTALL/bin/pip3
	if [ -f $PIP ]; then
		for module in $PYTHON_MODULES; do
			cmd="$PYTHON -x \"import $module\""
			$cmd $LOG_CMD > /dev/null 2>&1
			if [ $? != 0 ]; then
				cmd="$PIP install $module"
				run_cmd "$cmd $LOG_CMD"
				echo "Python module '$module' successfully installed"
			else
				echo "Python module '$module' already installed skipping"
			fi
		done
	else
		echo "Python-$PYTHON_VERSION has not built 'pip' tool correctly !!!"
		exit 1
	fi
}

if [ -d $INSTALL ]; then
	echo "ERROR: Python installation '$INSTALL' already exist"
	echo "Skipping python-$PYTHON_VERSION installation"
	install_modules
else
	echo "Installing python-$PYTHON_VERSION"
	init
	get_src
	build_install
	install_modules
fi
