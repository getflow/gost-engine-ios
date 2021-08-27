#!/bin/sh

set -e

# DOWNLOAD
rm -rf engine
git clone --recurse-submodules -b dev/static_build https://github.com/kartaris/engine.git


# BUILD
export OUTDIR=output
export BUILDDIR=build
export IPHONEOS_DEPLOYMENT_TARGET="9.3"

ROOTDIR="${PWD}"

function build() {
	ARCH=${1}
    HOST=${2}
    SDKDIR=${3}	
    LOG="../${ARCH}_build.log"

    CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SDKDIR} -miphoneos-version-min=${IPHONEOS_DEPLOYMENT_TARGET}"
    LDFLAGS="-arch ${ARCH} -isysroot ${SDKDIR}"

    WORKDIR=${ARCH}/gost-engine
    mkdir -p ${WORKDIR}
    cd ${WORKDIR}

    echo "Building gost-engine for ${ARCH}..."

    cmake -DOPENSSL_INCLUDE_DIR=${ROOTDIR}/${OUTDIR}/combined/openssl/include \
		-DOPENSSL_LIBRARIES=${ROOTDIR}/${OUTDIR}/combined/openssl/lib \
		-DOPENSSL_ROOT_DIR=${ROOTDIR}/${OUTDIR}combined/openssl \
		-DCMAKE_BUILD_TYPE=Release \
		-DOPENSSL_CRYPTO_LIBRARY=${ROOTDIR}/${OUTDIR}/combined/openssl/lib/libcrypto.a \
		-DOPENSSL_SSL_LIBRARY=${ROOTDIR}/${OUTDIR}/combined/openssl/lib/libssl.a \
		-DOPENSSL_ENGINES_DIR=${ROOTDIR}/${OUTDIR}/combined/openssl/lib/engines-1.1 \
		-G "Unix Makefiles" \
		-DCMAKE_OSX_SYSROOT=${SDKDIR} \
        -DCMAKE_C_COMPILER=$(xcrun -find -sdk iphoneos clang) \
        -DCMAKE_C_FLAGS="$CFLAGS" \
        -DCMAKE_LD_FLAGS="$LDFLAGS" \
		${ROOTDIR}/engine >> "${LOG}" 2>&1

	# cmake -DOPENSSL_INCLUDE_DIR=${ROOTDIR}/${OUTDIR}/combined/openssl/include \
	# 	-DOPENSSL_LIBRARIES=${ROOTDIR}/${OUTDIR}/combined/openssl/lib \
	# 	-DOPENSSL_ROOT_DIR=${ROOTDIR}/${OUTDIR}combined/openssl \
	# 	-DCMAKE_BUILD_TYPE=Release \
	# 	-DCMAKE_SYSTEM_NAME=iOS \
	# 	-DOPENSSL_CRYPTO_LIBRARY=${ROOTDIR}/${OUTDIR}/combined/openssl/lib/libcrypto.a \
	# 	-DOPENSSL_SSL_LIBRARY=${ROOTDIR}/${OUTDIR}/combined/openssl/lib/libssl.a \
	# 	-DOPENSSL_ENGINES_DIR=${ROOTDIR}/${OUTDIR}/combined/openssl/lib/engines-1.1 \
	# 	-G "Unix Makefiles" \
	# 	${ROOTDIR}/engine

		# -DCMAKE_SYSTEM_NAME=iOS \
		# -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
		# -DCMAKE_SYSTEM_PROCESSOR=${ARCH} \
		# -DCMAKE_OSX_DEPLOYMENT_TARGET=${IPHONEOS_DEPLOYMENT_TARGET} \
		# -DCMAKE_SKIP_INSTALL_RULES=TRUE \
		# -DCMAKE_MACOSX_BUNDLE=OFF \

		# --debug-output \

	# cmake -DOPENSSL_INCLUDE_DIR=${ROOTDIR}/${OUTDIR}/include \
	# 	-DOPENSSL_LIBRARIES=${ROOTDIR}/${OUTDIR}/lib \
	# 	-DOPENSSL_ROOT_DIR=${ROOTDIR}/${OUTDIR} \
	# 	-DOPENSSL_ENGINES_DIR=${ROOTDIR}/${OUTDIR}/lib/engines-1.1 \
	# 	-DCMAKE_BUILD_TYPE=Release \
	# 	-DCMAKE_TOOLCHAIN_FILE=${ROOTDIR}/${BUILDDIR}/ios.toolchain.cmake \
	# 	-DPLATFORM=OS64 \
	# 	-DENABLE_BITCODE=false \
	# 	-DENABLE_VISISBILITY=false \
	# 	-G Xcode \
	# 	${ROOTDIR}/engine

	# cmake -DOPENSSL_INCLUDE_DIR=${ROOTDIR}/${OUTDIR}/include \
	# 	-DOPENSSL_LIBRARIES=${ROOTDIR}/${OUTDIR}/lib \
	# 	-DOPENSSL_ROOT_DIR=${ROOTDIR}/${OUTDIR} \
	# 	-DOPENSSL_ENGINES_DIR=${ROOTDIR}/${OUTDIR}/lib/engines-1.1 \
	# 	-DCMAKE_BUILD_TYPE=Release \
	# 	${ROOTDIR}/engine

	# export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SDKDIR} -miphoneos-version-min=${IPHONEOS_DEPLOYMENT_TARGET}"
    # export LDFLAGS="-arch ${ARCH} -isysroot ${SDKDIR}"

	cmake --build . --config Release >> "${LOG}" 2>&1

	mkdir -p ${ROOTDIR}/${OUTDIR}/${ARCH}/gost-engine/lib
	mkdir -p ${ROOTDIR}/${OUTDIR}/${ARCH}/gost-engine/include/gost-engine/

	cp -r lib*.a ${ROOTDIR}/${OUTDIR}/${ARCH}/gost-engine/lib

	cd ../..
}

rm -rf $OUTDIR $BUILDDIR
mkdir $OUTDIR
mkdir $BUILDDIR

# OPENSSL
rm -f openssl-build-ios.sh
curl "https://raw.githubusercontent.com/kartaris/openssl-ios/master/build-ios.sh" > openssl-build-ios.sh
bash openssl-build-ios.sh 1.1.1d

mkdir -p $BUILDDIR
cd $BUILDDIR

# curl "https://raw.githubusercontent.com/leetal/ios-cmake/master/ios.toolchain.cmake" > ios.toolchain.cmake

build arm64   ios64-xcrun         $(xcrun --sdk iphoneos --show-sdk-path)
build x86_64  iossimulator-xcrun  $(xcrun --sdk iphonesimulator --show-sdk-path)
build armv7   ios-xcrun           $(xcrun --sdk iphoneos --show-sdk-path)

cd ../

mkdir -p ${OUTDIR}/combined/gost-engine/include/gost-engine/
mkdir -p ${OUTDIR}/combined/gost-engine/lib/

lipo -arch armv7 ${OUTDIR}/armv7/gost-engine/lib/libgost.a \
   -arch arm64 ${OUTDIR}/arm64/gost-engine/lib/libgost.a \
   -arch x86_64 ${OUTDIR}/x86_64/gost-engine/lib/libgost.a \
   -create -output ${OUTDIR}/combined/gost-engine/lib/libgost.a

lipo -arch armv7 ${OUTDIR}/armv7/gost-engine/lib/libgost_core.a \
   -arch arm64 ${OUTDIR}/arm64/gost-engine/lib/libgost_core.a \
   -arch x86_64 ${OUTDIR}/x86_64/gost-engine/lib/libgost_core.a \
   -create -output ${OUTDIR}/combined/gost-engine/lib/libgost_core.a

###########
# PACKAGE #
###########

FWNAME=gost-engine

if [ -d ${FWNAME}.framework ]; then
    echo "Removing previous ${FWNAME}.framework copy"
    rm -rf ${FWNAME}.framework
fi

LIBTOOL_FLAGS="-no_warning_for_no_symbols -static"

echo "Creating ${FWNAME}.framework"
mkdir -p ${FWNAME}.framework/Headers/
libtool ${LIBTOOL_FLAGS} -o ${FWNAME}.framework/${FWNAME} ${OUTDIR}/combined/gost-engine/lib/libgost.a ${OUTDIR}/combined/gost-engine/lib/libgost_core.a
cp -r ${ROOTDIR}/engine/*.h ${FWNAME}.framework/Headers/

rm -rf ${BUILDDIR}
# rm -rf ${OUTDIR}/armv7
# rm -rf ${OUTDIR}/arm64
# rm -rf ${OUTDIR}/x86_64

cp "Info.plist" ${FWNAME}.framework/Info.plist

set +e
check_bitcode=$(otool -arch arm64 -l ${FWNAME}.framework/${FWNAME} | grep __bitcode)
if [ -z "${check_bitcode}" ]
then
    echo "INFO: ${FWNAME}.framework doesn't contain Bitcode"
else
    echo "INFO: ${FWNAME}.framework contains Bitcode"
fi
