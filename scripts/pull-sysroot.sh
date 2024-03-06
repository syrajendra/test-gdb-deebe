#!/bin/sh
#-----------------------------------------#
# Copyright (c) 2020-2023 by Rajendra S Y #
# All rights reserved.                    #
#-----------------------------------------#

# remote machine
RMACHINE=$1

# passwdless access
#cat ~/.ssh/id_rsa.pub | ssh $RMACHINE 'cat >> ~/.ssh/authorized_keys'

export BOARD_OS=`ssh $RMACHINE uname -s`
if [ "$BOARD_OS" = "FreeBSD" ]; then
    export BOARD_CC=clang
elif [ "$BOARD_OS" = "Linux" ]; then
    export BOARD_CC=gcc
else
    echo "ERROR: Board os not supported"
    exit 1
fi

# find out the target triple
TRIPLE=`ssh $RMACHINE "$BOARD_CC -dumpmachine"`
mkdir -p $TRIPLE

cd $TRIPLE
rsync -arvz $RMACHINE:/lib .
rsync -arvz $RMACHINE:/libexec .
mkdir usr
cd usr
rsync -arvz $RMACHINE:/usr/include .
rsync -arvz $RMACHINE:/usr/libexec .
rsync -arvz $RMACHINE:/usr/libdata .
rsync -arvz $RMACHINE:/usr/lib .


