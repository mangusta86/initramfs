#!/bin/bash

# location
if [ "${1}" != "" ]; then
	export INITRAMFS_SOURCE=`readlink -f ${1}`;
else
	export INITRAMFS_SOURCE=`readlink -f .`;
fi;

export INITRAMFS_TMP=/tmp/initramfs_source;

# remove previous initramfs files
if [ -d $INITRAMFS_TMP ]; then
	echo "removing old temp initramfs_source";
	rm -rf $INITRAMFS_TMP;
fi;

# clean initramfs old compile data
rm -rf $INITRAMFS_SOURCE/OUTPUT;

cp -ax $INITRAMFS_SOURCE $INITRAMFS_TMP;

# clear git repository from tmp-initramfs
if [ -d $INITRAMFS_TMP/.git ]; then
	rm -rf $INITRAMFS_TMP/.git;
fi;

# clear mercurial repository from tmp-initramfs
if [ -d $INITRAMFS_TMP/.hg ]; then
	rm -rf $INITRAMFS_TMP/.hg;
fi;

# remove empty directory placeholders from tmp-initramfs
for i in `find $INITRAMFS_TMP -name EMPTY_DIRECTORY`; do
	rm -f $i;
done;

# remove more from from tmp-initramfs ...
rm -f $INITRAMFS_TMP/compress-sql.sh;
rm -f $INITRAMFS_TMP/update*;
rm -f $INITRAMFS_TMP/pack-initramfs.sh;
rm -f $INITRAMFS_TMP/kernel;
rm -f $INITRAMFS_TMP/mkbootimg;

mkdir $INITRAMFS_SOURCE/OUTPUT;

cd $INITRAMFS_TMP;
find . | cpio -o -H newc | gzip > $INITRAMFS_SOURCE/OUTPUT/ramdisk.cpio.gz
cd $INITRAMFS_SOURCE;	

# make boot image
        ./mkbootimg --cmdline '$CMDLINE' --kernel $INITRAMFS_SOURCE/kernel --ramdisk $INITRAMFS_SOURCE/OUTPUT/ramdisk.cpio.gz --base 0x00000000 --ramdiskaddr 0x01000000 --pagesize 2048 -o $INITRAMFS_SOURCE/OUTPUT/boot.img
