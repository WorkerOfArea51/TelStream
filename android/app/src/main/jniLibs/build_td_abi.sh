#!/bin/bash -e

__DIR__="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
if [ -z "$ANDROID_NDK_HOME" ]; then
	echo >&2 "ANDROID_NDK_HOME not set"
	exit 2
fi
if [ -z "$1" ]; then
	exit 2
fi
abi=$1

mkdir -p $__DIR__/build/td/$abi
cd $__DIR__/build/td/$abi

OPENSSL_ROOT_DIR="../../../openssl"
OPENSSL_CRYPTO_LIBRARY="$OPENSSL_ROOT_DIR/$abi/lib/libcrypto.a"
OPENSSL_SSL_LIBRARY="$OPENSSL_ROOT_DIR/$abi/lib/libssl.a"

# Use relative paths and prefix maps to strip PII and absolute system paths from the compiled binary
cmake ../../../td -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DANDROID_ABI=${abi} \
	-DCMAKE_C_FLAGS="-ffile-prefix-map=$__DIR__=." \
	-DCMAKE_CXX_FLAGS="-ffile-prefix-map=$__DIR__=." \
	-DOPENSSL_FOUND=1 \
	-DOPENSSL_INCLUDE_DIR="$OPENSSL_ROOT_DIR/include" \
	-DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_CRYPTO_LIBRARY" \
	-DOPENSSL_SSL_LIBRARY="$OPENSSL_SSL_LIBRARY" \
	-DOPENSSL_LIBRARIES="$OPENSSL_SSL_LIBRARY;$OPENSSL_CRYPTO_LIBRARY" || exit 1
cmake --build . || exit 1
