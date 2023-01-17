#!/bin/bash
set -e
################## SETUP BEGIN
# brew install git git-lfs
THREAD_COUNT=$(sysctl hw.ncpu | awk '{print $2}')
HOST_ARC=$( uname -m )
XCODE_ROOT=$( xcode-select -print-path )
OPENSSL_VER=OpenSSL_1_1_1o
################## SETUP END
#DEVSYSROOT=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer
#SIMSYSROOT=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer
MACSYSROOT=$XCODE_ROOT/Platforms/MacOSX.platform/Developer
OPENSSL_VER_NAME=${OPENSSL_VER//.//-}
BUILD_DIR="$( cd "$( dirname "./" )" >/dev/null 2>&1 && pwd )"

if [ "$HOST_ARC" = "arm64" ]; then
	BUILD_ARC=arm
else
	BUILD_ARC=$HOST_ARC
fi

if [ ! -d $BUILD_DIR/frameworks ]; then

if [ ! -d $OPENSSL_VER_NAME ]; then
	echo downloading $OPENSSL_VER ...
	git clone --depth 1 -b $OPENSSL_VER https://github.com/openssl/openssl $OPENSSL_VER_NAME
fi

echo building $OPENSSL_VER "(-j$THREAD_COUNT)" ...
pushd $OPENSSL_VER_NAME

if [ -d $BUILD_DIR/build ]; then
	rm -rf $BUILD_DIR/build
fi

if [ ! -d $BUILD_DIR/build/lib ]; then
./Configure --prefix="$BUILD_DIR/build" --openssldir="$BUILD_DIR/build/ssl" no-shared darwin64-$HOST_ARC-cc -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
make clean
make -j$THREAD_COUNT
make install
make clean
fi

if [ ! -d $BUILD_DIR/build/lib.catalyst ]; then
./Configure --prefix="$BUILD_DIR/build" --openssldir="$BUILD_DIR/build/ssl" no-shared darwin64-$HOST_ARC-cc --target=$BUILD_ARC-apple-ios13.4-macabi -isysroot $MACSYSROOT/SDKs/MacOSX.sdk -I$MACSYSROOT/SDKs/MacOSX.sdk/System/iOSSupport/usr/include/ -isystem $MACSYSROOT/SDKs/MacOSX.sdk/System/iOSSupport/usr/include -iframework $MACSYSROOT/SDKs/MacOSX.sdk/System/iOSSupport/System/Library/Frameworks
make clean
make -j$THREAD_COUNT

mkdir $BUILD_DIR/build/lib.catalyst
cp libssl.a $BUILD_DIR/build/lib.catalyst/
cp libcrypto.a $BUILD_DIR/build/lib.catalyst/
make clean
fi

if [ ! -d $BUILD_DIR/build/lib.iossim_host ]; then
./Configure --prefix="$BUILD_DIR/build" --openssldir="$BUILD_DIR/build/ssl" no-shared iossimulator-xcrun -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
make clean
make -j$THREAD_COUNT

mkdir $BUILD_DIR/build/lib.iossim_host
cp libssl.a $BUILD_DIR/build/lib.iossim_host/
cp libcrypto.a $BUILD_DIR/build/lib.iossim_host/
make clean
fi

if [ -d $BUILD_DIR/build/lib.iossim ]; then
	rm -rf $BUILD_DIR/build/lib.iossim
fi
mkdir $BUILD_DIR/build/lib.iossim

# if [ $HOST_ARC == "arm64" ]; then
# if [ ! -d $BUILD_DIR/build/lib.iossim_x86_64 ]; then
# ./Configure --prefix="$BUILD_DIR/build" --openssldir="$BUILD_DIR/build/ssl" no-shared iossimulator-xcrun CFLAGS="-arch x86_64" -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
# make clean
# make -j$THREAD_COUNT

# mkdir $BUILD_DIR/build/lib.iossim_x86_64
# cp libssl.a $BUILD_DIR/build/lib.iossim_x86_64/
# cp libcrypto.a $BUILD_DIR/build/lib.iossim_x86_64/
# make clean
# fi

# lipo -create $BUILD_DIR/build/lib.iossim_x86_64/libssl.a $BUILD_DIR/build/lib.iossim_host/libssl.a -output $BUILD_DIR/build/lib.iossim/libssl.a
# lipo -create $BUILD_DIR/build/lib.iossim_x86_64/libcrypto.a $BUILD_DIR/build/lib.iossim_host/libcrypto.a -output $BUILD_DIR/build/lib.iossim/libcrypto.a

# else
	cp $BUILD_DIR/build/lib.iossim_host/*.a $BUILD_DIR/build/lib.iossim/
# fi

if [ ! -d $BUILD_DIR/build/lib.ios ]; then
./Configure --prefix="$BUILD_DIR/build" --openssldir="$BUILD_DIR/build/ssl" no-shared no-dso no-hw no-engine ios64-xcrun -fembed-bitcode -mios-version-min=13.0 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
make clean
make -j$THREAD_COUNT

mkdir $BUILD_DIR/build/lib.ios
cp libssl.a $BUILD_DIR/build/lib.ios/
cp libcrypto.a $BUILD_DIR/build/lib.ios/
make clean
fi

mkdir $BUILD_DIR/frameworks

cp -R $BUILD_DIR/build/include $BUILD_DIR/frameworks/Headers

xcodebuild -create-xcframework -library $BUILD_DIR/build/lib/libssl.a -library $BUILD_DIR/build/lib.catalyst/libssl.a -library $BUILD_DIR/build/lib.iossim/libssl.a -library $BUILD_DIR/build/lib.ios/libssl.a -output $BUILD_DIR/frameworks/ssl.xcframework
xcodebuild -create-xcframework -library $BUILD_DIR/build/lib/libcrypto.a -library $BUILD_DIR/build/lib.catalyst/libcrypto.a -library $BUILD_DIR/build/lib.iossim/libcrypto.a -library $BUILD_DIR/build/lib.ios/libcrypto.a -output $BUILD_DIR/frameworks/crypto.xcframework

popd

fi
