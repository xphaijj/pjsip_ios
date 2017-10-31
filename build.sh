#!/bin/bash


BASEPATH=$(cd "$(dirname "$0")"; pwd)

BASE_FOLDER="${BASEPATH}/pjproject-2.7"
LIBRARY_PATH="${BASEPATH}/output"
HEADER_PATH="$LIBRARY_PATH/pjsip-include"
FAT_LIBRARY_PATH="$LIBRARY_PATH/pjsip-lib"
DEVPATH="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer"

ARCH_LIST="x86_64 i386 armv7 armv7s arm64"

####### header 部分处理
PJLIB_PATH="${BASE_FOLDER}/pjlib"
PJLIB_UTIL_PATH="${BASE_FOLDER}/pjlib-util"
PJMEDIA_PATH="${BASE_FOLDER}/pjmedia"
PJNATH_PATH="${BASE_FOLDER}/pjnath"
PJSIP_PATH="${BASE_FOLDER}/pjsip"
PJ_THIRD_PARTY_PATH="${BASE_FOLDER}/third_party"

TARGET_HEADER_PATHS=("${PJLIB_PATH}" "${PJLIB_UTIL_PATH}" "${PJMEDIA_PATH}" "${PJNATH_PATH}" "${PJSIP_PATH}")

function config_site() {
    PJSIP_CONFIG_PATH="${PJLIB_PATH}/include/pj/config_site.h"
    # HAS_VIDEO=

    echo "Creating config_site.h ..."

    if [ -f "${PJSIP_CONFIG_PATH}" ]; then
        rm "${PJSIP_CONFIG_PATH}"
    fi

    echo "#define PJ_CONFIG_IPHONE 1" >> "${PJSIP_CONFIG_PATH}"
    echo "#define PJ_HAS_IPV6 1" >> "${PJSIP_CONFIG_PATH}" # Enable IPV6
    # if [[ ${OPENH264_PREFIX} ]]; then
    #     echo "#define PJMEDIA_HAS_OPENH264_CODEC 1" >> "${PJSIP_CONFIG_PATH}"
    #     HAS_VIDEO=1
    # fi
    # if [[ ${HAS_VIDEO} ]]; then
    #     echo "#define PJMEDIA_HAS_VIDEO 1" >> "${PJSIP_CONFIG_PATH}"
    #     echo "#define PJMEDIA_VIDEO_DEV_HAS_OPENGL 1" >> "${PJSIP_CONFIG_PATH}"
    #     echo "#define PJMEDIA_VIDEO_DEV_HAS_OPENGL_ES 1" >> "${PJSIP_CONFIG_PATH}"
    #     echo "#define PJMEDIA_VIDEO_DEV_HAS_IOS_OPENGL 1" >> "${PJSIP_CONFIG_PATH}"
    #     echo "#include <OpenGLES/ES3/glext.h>" >> "${PJSIP_CONFIG_PATH}"
    # fi
    echo "#include <pj/config_site_sample.h>" >> "${PJSIP_CONFIG_PATH}"
}

function mkdirArch
{
    echo mkdirARch

    if [ ! -d "$LIBRARY_PATH" ]; then
        echo mkdir $LIBRARY_PATH
        mkdir $LIBRARY_PATH
    fi

	if [ ! -d "$HEADER_PATH" ]; then
        echo mkdir $HEADER_PATH
        mkdir $HEADER_PATH
    fi    

    if [ ! -d "$FAT_LIBRARY_PATH" ]; then
        echo mkdir $FAT_LIBRARY_PATH
        mkdir $FAT_LIBRARY_PATH
    fi

    for arch in $ARCH_LIST;
    do
        if [ ! -d "$LIBRARY_PATH/$arch" ]; then
            echo mkdir $LIBRARY_PATH/$arch
            mkdir $LIBRARY_PATH/$arch
        fi
    done
}

function makeHeader 
{
	#Make directory for all pjsip headers
	rm -rf "${HEADER_PATH}"
	mkdir -p "${HEADER_PATH}"

	#Copy all header files under single folder
	for path in "${TARGET_HEADER_PATHS[@]}"
	do
		echo "Coping header files from $path to $HEADER_PATH"
		cp -r "${path}/include/" "${HEADER_PATH}"
	done
}

function makeLibrary
{
    echo makeLibrary
    for arch in $ARCH_LIST;
    do
        cd $BASE_FOLDER

        if [ "$arch" == "i386" || "$arch" == "x86_64" ]
        then
            ARCH="-arch $arch" CFLAGS="-O2 -m32 -mios-simulator-version-min=5.0" LDFLAGS="-O2 -m32 -mios-simulator-version-min=5.0" \
                DEVPATH="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer" \
                ./configure-iphone --prefix=`pwd`/$LIBRARY_PATH/$arch/ && make dep && make clean && make
        else
            ARCH="-arch $arch" ./configure-iphone --prefix=`pwd`/$LIBRARY_PATH/$arch/ && make dep && make clean && make
        fi

        libraryList=`find . -name *apple-darwin_ios.a`
        cd ..

        for lib in $libraryList
        do
            libraryName=${lib##*/}
            mv $BASE_FOLDER/$lib $LIBRARY_PATH/$arch/$libraryName
        done
    done
}

function makeFatLibraries
{
    libraryList=`find $LIBRARY_PATH/arm64 -name *apple-darwin_ios.a`

    for LIB_NAME in $libraryList
    do
        lipoArchArgs=""
        for arch in $ARCH_LIST;
        do
            archName=${LIB_NAME//arm64/$arch}
            lipoArchArgs="$lipoArchArgs -arch $arch $LIBRARY_PATH/$arch/`basename $archName`"
        done

        echo $lipoArchArgs | xargs lipo -create -output $FAT_LIBRARY_PATH/`basename $LIB_NAME`
        lipo -info $FAT_LIBRARY_PATH/`basename $LIB_NAME`
    done
}

function makeClean {
    for arch in $ARCH_LIST;
    do
        if [ -d "$LIBRARY_PATH/$arch" ]; then
            rm -rf $LIBRARY_PATH/$arch
        fi
    done
}


config_site
mkdirArch
makeLibrary
makeHeader
makeFatLibraries
makeClean

