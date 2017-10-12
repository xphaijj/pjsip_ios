#!/bin/bash

./scripts/build-libssl.sh

BASEPATH=$(cd "$(dirname "$0")"; pwd)

BASE_FOLDER="${BASEPATH}/pjproject-2.7"
BASE_FOLDER_SSL="${BASEPATH}/bin"
BASE_FOLDER_SSL_LIB="${BASEPATH}/lib"
LIBRARY_PATH="${BASEPATH}/output"
HEADER_PATH="$LIBRARY_PATH/pjsip-include"
FAT_LIBRARY_PATH="$LIBRARY_PATH/pjsip-lib"
DEVPATH="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer"

ARCH_LIST="i386 armv7 armv7s arm64"
IOS_VERSION="11.0"

####### header 部分处理
PJLIB_PATH="${BASE_FOLDER}/pjlib"
PJLIB_UTIL_PATH="${BASE_FOLDER}/pjlib-util"
PJMEDIA_PATH="${BASE_FOLDER}/pjmedia"
PJNATH_PATH="${BASE_FOLDER}/pjnath"
PJSIP_PATH="${BASE_FOLDER}/pjsip"
PJ_THIRD_PARTY_PATH="${BASE_FOLDER}/third_party"

TARGET_HEADER_PATHS=("${PJLIB_PATH}" "${PJLIB_UTIL_PATH}" "${PJMEDIA_PATH}" "${PJNATH_PATH}" "${PJSIP_PATH}")

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
        OPENSSL_PATH="${BASE_FOLDER_SSL}/iPhoneOS${IOS_VERSION}-${arch}.sdk/"

        if [ "$arch" == "i386" ]
        then
        OPENSSL_PATH="${BASE_FOLDER_SSL}/iPhoneSimulator${IOS_VERSION}-${arch}.sdk/"
        ARCH="-arch $arch" CFLAGS="-O2 -m32 -mios-simulator-version-min=5.0" LDFLAGS="-O2 -m32 -mios-simulator-version-min=5.0" \
                DEVPATH="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer" \
                ./configure-iphone --with-ssl="${OPENSSL_PATH}" --prefix=`pwd`/$LIBRARY_PATH/$arch/ && make dep && make clean && make
        else
            ARCH="-arch $arch" ./configure-iphone --with-ssl="${OPENSSL_PATH}" --prefix=`pwd`/$LIBRARY_PATH/$arch/ && make dep && make clean && make
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


mkdirArch
makeLibrary
makeHeader
makeFatLibraries
makeClean

