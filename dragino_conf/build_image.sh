#!/usr/bin/env bash
#Build Arduino Yun Image for Dragino2. MS14, HE. 

SFLAG=
AFLAG=
BFLAG=

DEFAULT_APP="lgw"
APP="lgw"
APP2=
IMAGE_SUFFIX=
BUILD_TIME=`date +%s`
REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="5.4.$BUILD_TIME"
OPENWRT_PATH=".."

while getopts 'a:b:p:v:sh' OPTION
do
	case $OPTION in
	a)
		AFLAG=1
		APP="$OPTARG"
		;;
	b)
		BFLAG=1
		APP2="$OPTARG"
		;;

	p)	OPENWRT_PATH="$OPTARG"
		;;

	v)	VERSION="$OPTARG"
		;;

	s)	SFLAG=1
		;;

	h|?)	printf "Build Image for Dragino MS14, HE, LG02, OLG02 \n\n"
		printf "Usage: %s [-p <openwrt_source_path>] [-a <application>]  [-v <version>] [-s] \n" $(basename $0) >&2
		printf "	-p: openwrt source path, default: .\n"
		printf "	-a: application default: Dragino_Yun\n"
		printf "	-v: specify firmware version\n"
		printf "	-s: build in singe thread\n"
		printf "\n"
		exit 1
		;;
	esac
done

shift $(($OPTIND - 1))

# Convert OPENWRT_PATH to absolute path relative to REPO_PATH
if [[ "$OPENWRT_PATH" != /* ]]; then
	OPENWRT_PATH="$(cd "$REPO_PATH/$OPENWRT_PATH" 2>/dev/null && pwd)"
fi

BUILD=$APP-$VERSION

BUILD_TIME="`date`"
ARCH="ath79"

file_prefix="openwrt-ath79-generic-dragino_lps8n"
name_prefix="dragino-$APP"
if [ -n "$APP2" ]; then
	name_prefix="$name_prefix-$APP2"
fi

target_path="bin/targets/ath79/generic"

#if [ ! -z $APP ];then
#    file_prefix=$file_prefix"-"$APP
#fi

if [ $APP = "duo" ];then
	echo "Arch is ramips"
	ARCH="ramips"
	file_prefix="openwrt-ramips-mt7628-DUO"
fi

# :<<!
# if [ $APP != "Navitas" ]; then
#     echo "$APP: PATCH enable UART"
#     rm  -vf openwrt/target/linux/ar71xx/patches-4.9/520-MIPS-ath79-disable-UART-function.patch
#     cp -vf openwrt/target/linux/ar71xx/520-MIPS-ath79-enable-UART-function.patch.normal  openwrt/target/linux/ar71xx/patches-4.9/openwrt/target/linux/ar71xx/520-MIPS-ath79-enable-UART-function.patch
#     cp -vf openwrt/target/linux/ar71xx/521-MIPS-ath79-enable-UART-for-early_serial.patch openwrt/target/linux/ar71xx/patches-4.9
#     cp -vf openwrt/target/linux/ar71xx/config-4.9.lgw  openwrt/target/linux/ar71xx/config-4.9
# else
#     echo "$APP: PATCH disable UART"
#     rm  -vf openwrt/target/linux/ar71xx/patches-4.9/520-MIPS-ath79-enable-UART-function.patch
#     rm -vf openwrt/target/linux/ar71xx/patches-4.9/521-MIPS-ath79-enable-UART-for-early_serial.patch
#     cp  -vf openwrt/target/linux/ar71xx/520-MIPS-ath79-enable-UART-function.patch.disable-uart openwrt/target/linux/ar71xx/patches-4.9/520-MIPS-ath79-disable-UART-function.patch
#     cp -vf openwrt/target/linux/ar71xx/config-4.9.navitas  openwrt/target/linux/ar71xx/config-4.9
# fi

# !

echo ""

echo "Remove custom files from last build"

rm -rf $OPENWRT_PATH/files

echo "***Copy general_files to OpenWrt***"
cp -r $REPO_PATH/general_files $OPENWRT_PATH/files

echo "***.config.$APP to OpenWrt/.config***"
cp $REPO_PATH/.config.$APP $OPENWRT_PATH/.config

#cd $OPENWRT_PATH/feeds/dragino

#git pull 

cd $REPO_PATH

if [ -d files-$APP ];then
	echo "***Copy files-$APP to default files directory***"
	echo ""
	cp -r files-$APP/?* $OPENWRT_PATH/files/
elif [ "$APP" != "$DEFAULT_APP" ];then
	echo "***Can't find files-$APP***"
	echo "Use default files files-$DEFAULT_APP"
	echo ""
fi

if [ -f .config.$APP ];then
	echo ""
	echo "***Find customized .config files***"
	echo "Replace default .config file with .config.$APP"
	echo ""
	cp .config.$APP $OPENWRT_PATH/.config
else
	echo ""
	echo "***Can't find .config.$APP file***"
	echo "Use default .config.$DEFAULT_APP"
	echo ""
fi


#Copy the second level APP info. normally is OEM info
if [ ! -z $BFLAG ];then
	echo copying sub-files-$APP2
	cp -r sub-files-$APP2/* $OPENWRT_PATH/files/
	if [ -f .config.$APP2 ];then
		echo ""
		echo "***Find sub customized .config files***"
		echo "Replace default .config file with .config.$APP2"
		echo ""
		cp .config.$APP2 $OPENWRT_PATH/.config
	fi
fi

echo ""

echo "***Entering build directory***"

cd $OPENWRT_PATH

#make sure fresh the luci-app on each build
rm -rf build_dir/target-mips_24kc_musl/luci-app-*

echo ""

echo ""
echo "***Update build version and build date***"
echo "Build: $BUILD"
echo "Build Time: $BUILD_TIME"
sed -i "s/VERSION/$BUILD/g" files/etc/banner
sed -i "s/TIME/$BUILD_TIME/g" files/etc/banner
echo ""


echo ""
echo "***Cleaning old target images for $file_prefix***"
rm -f ./$target_path/$file_prefix-*.bin 2>/dev/null

echo ""
if [ ! -z $SFLAG ];then
	echo "***Run make for dragion ms14, HE in single thread ***"
	make V=s
else
	echo "***Run make for dragion ms14, HE, LG01N, LG02, LG308, LPS8, DLOS8, LIG16"
	make -j32 V=99
fi

# Check for initramfs-kernel.bin (primary) and sysupgrade.bin (rootfs type dependent)
INITRAMFS_FILE=$(ls ./$target_path/openwrt-*-initramfs-kernel.bin 2>/dev/null | head -1)
SYSUPGRADE_FILE=$(ls ./$target_path/$file_prefix-*-sysupgrade.bin 2>/dev/null | head -1)

if [ -z "$INITRAMFS_FILE" ] && [ -z "$SYSUPGRADE_FILE" ]; then
	echo ""
	echo "Build Fails, run below commands to build the image in single thread and check what is wrong"
	echo "**************"
	echo "	./build_image.sh -s V=99"
	echo "**************"
	exit 1
fi

# Copy built image to script directory
echo ""
echo "***Copying built image to script directory***"
if [ -n "$INITRAMFS_FILE" ]; then
	DEST_NAME="dragino-$APP-v$VERSION-initramfs-kernel.bin"
	cp "$INITRAMFS_FILE" "$REPO_PATH/$DEST_NAME"
	echo "Copied: $DEST_NAME"
fi
if [ -n "$SYSUPGRADE_FILE" ]; then
	SYSUPGRADE_BASE="$(basename "$SYSUPGRADE_FILE")"
	SYSUPGRADE_SUFFIX="${SYSUPGRADE_BASE#${file_prefix}-}"
	DEST_NAME="dragino-$APP-v$VERSION-$SYSUPGRADE_SUFFIX"
	cp "$SYSUPGRADE_FILE" "$REPO_PATH/$DEST_NAME"
	echo "Copied: $DEST_NAME"
fi

echo "Copy Image"
echo "Set up new directory name with date"
DATE=`date +%Y%m%d-%H%M`

mkdir -p $REPO_PATH/image/$APP-$APP2-build-v$VERSION-$DATE
IMAGE_DIR=$REPO_PATH/image/$APP-$APP2-build-v$VERSION-$DATE

echo ""
echo  "***Move files to ./image/$APP-$APP2-build--v$VERSION--$DATE ***"
if [ -n "$SYSUPGRADE_FILE" ]; then
	SYSUPGRADE_BASE="$(basename "$SYSUPGRADE_FILE")"
	SYSUPGRADE_SUFFIX="${SYSUPGRADE_BASE#${file_prefix}-}"
	cp "$SYSUPGRADE_FILE" "$IMAGE_DIR/$name_prefix-v$VERSION-$SYSUPGRADE_SUFFIX"
fi
if [ -n "$INITRAMFS_FILE" ]; then
	INITRAMFS_BASE="$(basename "$INITRAMFS_FILE")"
	INITRAMFS_SUFFIX="${INITRAMFS_BASE#${file_prefix}-}"
	cp "$INITRAMFS_FILE" "$IMAGE_DIR/$name_prefix-v$VERSION-$INITRAMFS_SUFFIX"
fi
ROOTFS_TAR="$(ls ./$target_path/openwrt-*-rootfs.tar.gz 2>/dev/null | head -1)"
ROOTFS_CPIO="$(ls ./$target_path/openwrt-*-rootfs.cpio.gz 2>/dev/null | head -1)"
MANIFEST_FILE="$(ls ./$target_path/openwrt-*.manifest 2>/dev/null | head -1)"
[ -n "$ROOTFS_TAR" ] && cp "$ROOTFS_TAR" "$IMAGE_DIR/$name_prefix-v$VERSION-rootfs.tar.gz"
[ -n "$ROOTFS_CPIO" ] && cp "$ROOTFS_CPIO" "$IMAGE_DIR/$name_prefix-v$VERSION-rootfs.cpio.gz"
[ -n "$MANIFEST_FILE" ] && cp "$MANIFEST_FILE" "$IMAGE_DIR/$name_prefix-v$VERSION.manifest"

echo ""
echo "***Update md5sums***"
cat ./$target_path/sha256sums | grep "$file_prefix" | awk '{gsub(/'"$file_prefix"'/,"'"$name_prefix"'-v'"$VERSION"'")}{print}' >> $IMAGE_DIR/sha256sums

echo ""
echo "***Back Up Custom Config to Image DIR***"
mkdir $IMAGE_DIR/custom_config
[ -f $REPO_PATH/.config.$APP ] && cp $REPO_PATH/.config.$APP $IMAGE_DIR/custom_config/.config
[ -f $REPO_PATH/.config.$APP2 ] && cp $REPO_PATH/.config.$APP2 $IMAGE_DIR/custom_config/.config.$APP2
[ -d $REPO_PATH/files-$APP ] && cp -r $REPO_PATH/files-$APP $IMAGE_DIR/custom_config/files
[ -d $REPO_PATH/sub-files-$APP2 ] && cp -r $REPO_PATH/sub-files-$APP2 $IMAGE_DIR/custom_config/files-$APP2
cd $IMAGE_DIR
tar zcvf custom_config.tar.gz custom_config
rm -rf custom_config

cd $REPO_PATH

echo ""
echo "End Dragino build, The image can be found at $IMAGE_DIR"
echo ""
