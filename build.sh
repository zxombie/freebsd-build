#!/bin/sh
# Copyright (c) 2016,2017 Andrew Turner
# All rights reserved.
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
# ("CTSRD"), as part of the DARPA CRASH research programme.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# A build script to make building FreeBSD simpler.
#
# On the first run use:
#   build.sh world kernel image
#
# This will build the FreeBSD userspace and kernel, install them into
# a local directory, and build an image from that directory.
#
# After the first run you can add noclean before world to only rebuild
# the parts that have changes. If you are only changing one part of the
# systems you can run:
#   build.sh noclean world installkernel image
# to rebuild the image with a new world or:
#   build.sh noclean kernel image
# to rebuild with a new kernel.
#
# The arguments are:
#  noclean -- Don't run make clean on targets after this point
#  noj -- Eun a single command at a time on targets after this point
#  continue -- Ignore errors on on targets after this point
#  verbose -- Include commands run on targets after this point
#
#  kernel-toolchain -- Build the FreeBSD kernel-toolchain (this is also part
#                      of buildworld & toolchain)
#  toolchain -- Build the FreeBSD toolchain (this is also part of buildworld)
#  buildworld -- Build the FreeBSD userspace
#  installworld -- Install the FreeVSD userspace
#  world -- Run buildworld then installworld
#  buildkernel -- Build the FreeBSD kernel and modules
#  installkernel -- Install the FreeBSD kernel and modules
#  kernel -- Run buildkernel then installkernel
#  image -- Build an image based on the installed world and kernel
#  buildenv -- Enter a shell to help building part of the tree

_BASE=`dirname $0`
export BASE=`realpath ${_BASE}`
export TARGET_ARCH=aarch64
#export TARGET_ARCH=armv7
export MAKEOBJDIRPREFIX="${HOME}/obj"
export SRC="/path/to/src/"
export ROOTFS=${MAKEOBJDIRPREFIX}/rootfs-freebsd-${TARGET_ARCH}

if [ "${SRC}" = "/path/to/src/" ] ; then
	echo "You need to edit $0 to set SRC to your source directory"
	exit 1
fi

NCPU=`sysctl -n hw.ncpu`
if [ -n "${NCPU}" ] ; then
	export JFLAG=-j`sysctl -n hw.ncpu`
fi

# Set this if you need extra files in the image
export EXTRAS_MTREE=""
#export EXTRAS_MTREE="${BASE}/extras/extras.mtree"

export KERNCONF="KERNCONF=GENERIC"

set -e

DASH_S="-s"

cd ${SRC}

noclean() {
	BUILD_FLAGS="${BUILD_FLAGS} -DNO_CLEAN"
}

noj() {
	JFLAG=""
}

cont() {
	BUILD_FLAGS="${BUILD_FLAGS} -k"
}

verbose() {
	DASH_S=""
}

kernel_toolchain() {
	make ${JFLAG} kernel-toolchain -s ${BUILD_FLAGS}
}

toolchain() {
	make ${JFLAG} toolchain ${DASH_S} ${BUILD_FLAGS}
}

#
# Build FreeBSD
#
buildworld() {
	make ${JFLAG} buildworld ${DASH_S} ${BUILD_FLAGS}
}

buildkernel() {
	make ${JFLAG} buildkernel ${DASH_S} ${BUILD_FLAGS} ${NO_MODULES} ${KERNCONF}
}

#
# Install FreeBSD
#
installworld() {
	make -DNO_ROOT -DDB_FROM_SRC DESTDIR=${ROOTFS} installworld ${BUILD_FLAGS}
	make -DNO_ROOT -DDB_FROM_SRC DESTDIR=${ROOTFS} distribution ${BUILD_FLAGS}
	echo '/dev/vtbd0s2	/	ufs	rw,noatime	1	1' > ${ROOTFS}/etc/fstab
	echo './etc/fstab type=file uname=root gname=wheel mode=644' >> ${ROOTFS}/METALOG
}

installkernel() {
	make -DNO_ROOT DESTDIR=${ROOTFS} installkernel ${NO_MODULES} \
	    ${KERNCONF} ${BUILD_FLAGS}
}

buildenv() {
	make buildenv
}

#
# Building an image
#
image() {
	EXTRA_ARGS=""
	if [ -n "${EXTRAS_MTREE}" ]
	then
		EXTRA_ARGS="-e ${EXTRAS_MTREE}"
	fi
	# Rootfs image. 2G
	#${BASE}/makeroot.sh -s 5368709120 -F 10000 -d ${EXTRA_ARGS} -e /scratch/tmp/andrew/pointerauth.mtree ${MAKEOBJDIRPREFIX}/rootfs-${TARGET_ARCH}.img ${ROOTFS}
	${SRC}/tools/tools/makeroot/makeroot.sh -s 5368709120 -d ${EXTRA_ARGS} ${MAKEOBJDIRPREFIX}/rootfs-${TARGET_ARCH}.img ${ROOTFS}

	# Final ARM64 image
	#mkimg -f qcow2 -s gpt -p efi:=${ROOTFS}/boot/boot1.efifat -p freebsd-ufs:=${MAKEOBJDIRPREFIX}/rootfs-${TARGET_ARCH}.img -o ${MAKEOBJDIRPREFIX}/disk-${TARGET_ARCH}.qcow2
	#mkimg -f qcow2 -s gpt -p efi:=${ROOTFS}/boot/boot1.efifat -p freebsd-ufs:=${MAKEOBJDIRPREFIX}/rootfs-${TARGET_ARCH}.img -o ${MAKEOBJDIRPREFIX}/disk-${TARGET_ARCH}.img
	mkimg -f raw -s gpt -p efi:=${ROOTFS}/boot/boot1.efifat -p freebsd-ufs:=${MAKEOBJDIRPREFIX}/rootfs-${TARGET_ARCH}.img -o ${MAKEOBJDIRPREFIX}/disk-${TARGET_ARCH}.img
}

while [ -n "$1" ] ; do
	case "$1" in
	noclean)
		noclean
		;;
	noj)
		noj
		;;
	continue)
		cont
		;;
	verbose)
		verbose
		;;
	toolchain)
		toolchain
		;;
	buildworld)
		buildworld
		;;
	installworld)
		installworld
		;;
	world)
		buildworld
		installworld
		;;
	buildkernel)
		buildkernel
		;;
	installkernel)
		installkernel
		;;
	kernel)
		buildkernel
		installkernel
		;;
	image)
		image
		;;
	buildenv)
		buildenv
		;;
	*)
		echo "Unknown command: $1"
		exit 1
		;;
	esac
	shift
done
