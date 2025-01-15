#!/bin/bash -eux

PATCHES="$PWD/patches"
SOURCE="${PDFium_SOURCE_DIR:-pdfium}"
OS="${PDFium_TARGET_OS:?}"
TARGET_ENVIRONMENT="${PDFium_TARGET_ENVIRONMENT:-}"

pushd "${SOURCE}"

[ "$OS" != "wasm" ] && git apply -v "$PATCHES/shared_library.patch"
git apply -v "$PATCHES/public_headers.patch"

[ "${PDFium_ENABLE_V8:-}" == "true" ] && git apply -v "$PATCHES/v8/pdfium.patch"

#always apply build_config_patch, doesn't hurt the other distro
pushd "${SOURCE}/build"
git apply -v "$PATCHES/build_config_ppc64le.patch"
popd

#Get libclang-rt for powerpc64le
pushd "${SOURCE}/third_party/llvm-build/Release+Asserts/lib/clang/20/lib/"
wget https://ibm.box.com/shared/static/7ez5z7vu75c0u2dno5t3anszwd2wrgdv.gz -O clang-rt-20-ppc.tar.gz
mkdir -p powerpc64le-unknown-linux-gnu
tar -xf clang-rt-20-ppc.tar.gz
rm -rf clang-rt-20-ppc.tar.gz
popd

case "$OS" in
  android)
    git -C build apply -v "$PATCHES/android/build.patch"
    ;;

  ios)
    git apply -v "$PATCHES/ios/pdfium.patch"
    [ "${PDFium_ENABLE_V8:-}" == "true" ] && git -C v8 apply -v "$PATCHES/ios/v8.patch"
    ;;

  linux)
    [ "${PDFium_ENABLE_V8:-}" == "true" ] && git -C v8 apply -v "$PATCHES/linux/v8.patch"
    ;;

  wasm)
    git apply -v "$PATCHES/wasm/pdfium.patch"
    git -C build apply -v "$PATCHES/wasm/build.patch"
    mkdir -p "build/toolchain/wasm"
    cp "$PATCHES/wasm/toolchain.gn" "build/toolchain/wasm/BUILD.gn"
    mkdir -p "build/config/wasm"
    cp "$PATCHES/wasm/config.gn" "build/config/wasm/BUILD.gn"
    ;;

  win)
    git -C build apply -v "$PATCHES/win/build.patch"

    VERSION=${PDFium_VERSION:-0.0.0.0}
    YEAR=$(date +%Y)
    VERSION_CSV=${VERSION//./,}
    export YEAR VERSION VERSION_CSV
    envsubst < "$PATCHES/win/resources.rc" > "resources.rc"
    ;;
esac

case "$TARGET_ENVIRONMENT" in
  musl)
    git apply -v "$PATCHES/musl/pdfium.patch"
    git -C build apply -v "$PATCHES/musl/build.patch"
    mkdir -p "build/toolchain/linux/musl"
    cp "$PATCHES/musl/toolchain.gn" "build/toolchain/linux/musl/BUILD.gn"
    ;;
esac

"$PATCHES/aggregate_licenses.sh"

popd
