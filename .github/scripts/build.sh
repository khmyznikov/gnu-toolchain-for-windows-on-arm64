#!/bin/bash

source `dirname ${BASH_SOURCE[0]}`/config.sh

if [[ "$RUN_BOOTSTRAP" = 1 ]]; then
    $ROOT_PATH/.github/scripts/install-dependencies.sh
fi

if [[ "$CCACHE" = 1 ]]; then
    source $ROOT_PATH/.github/scripts/enable-ccache.sh
fi

if [[ "$UPDATE_SOURCES" = 1 ]]; then
    $ROOT_PATH/.github/scripts/update-sources.sh
fi

if [[ "$HOST" == aarch64*-*-mingw* ]]; then
    for PROJECT in binutils gcc; do
        NATIVE_PATCH=$ROOT_PATH/.github/scripts/toolchain/$PROJECT-native-host.patch
        if ! git -C "$SOURCE_PATH/$PROJECT" apply --reverse --check "$NATIVE_PATCH" 2>/dev/null; then
            git -C "$SOURCE_PATH/$PROJECT" apply "$NATIVE_PATCH"
        fi
    done
fi

if [[ "$RUN_BOOTSTRAP" = 1 || "$RESET_SOURCES" = 1 ]]; then
    $ROOT_PATH/.github/scripts/install-libraries.sh
fi

if [[ "$CCACHE" = 1 ]]; then
    ccache $CCACHE_STATISTICS
fi

$ROOT_PATH/.github/scripts/binutils/build.sh

if [[ "$PLATFORM" =~ linux ]]; then
    $ROOT_PATH/.github/scripts/toolchain/install-cross-headers-libs.sh
fi
if [[ "$PLATFORM" =~ (mingw|cygwin) ]]; then
    $ROOT_PATH/.github/scripts/toolchain/build-mingw-headers.sh
fi
if [[ "$PLATFORM" =~ cygwin ]]; then
    $ROOT_PATH/.github/scripts/toolchain/install-cygwin-headers.sh
fi

# Canadian builds use the existing build-to-target cross-compiler.
if [[ "$BUILD" != "$TARGET" && "$BUILD" = "$HOST" ]]; then
    $ROOT_PATH/.github/scripts/toolchain/build-gcc-stage1.sh
elif [[ "$BUILD" != "$HOST" ]]; then
    cp "$ROOT_PATH/.github/scripts/toolchain/toolchain.sh" "$TOOLCHAIN_PATH"
fi

if [[ "$PLATFORM" =~ (mingw|cygwin) ]]; then
    $ROOT_PATH/.github/scripts/toolchain/build-mingw-crt.sh
fi
if [[ "$PLATFORM" =~ mingw ]]; then
    $ROOT_PATH/.github/scripts/toolchain/build-mingw-winpthreads.sh
fi
if [[ "$PLATFORM" =~ cygwin ]]; then
    $ROOT_PATH/.github/scripts/toolchain/build-cocom.sh
    $ROOT_PATH/.github/scripts/toolchain/build-cygwin.sh 1
fi

$ROOT_PATH/.github/scripts/toolchain/build-gcc.sh

if [[ "$PLATFORM" =~ mingw ]]; then
    $ROOT_PATH/.github/scripts/toolchain/build-mingw.sh
fi
if [[ "$PLATFORM" =~ cygwin ]]; then
    $ROOT_PATH/.github/scripts/toolchain/build-cygwin.sh 2
fi

if [[ "$CCACHE" = 1 ]]; then
    ccache $CCACHE_STATISTICS
fi

echo 'Success!'
