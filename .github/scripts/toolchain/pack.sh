#!/bin/bash

source `dirname ${BASH_SOURCE[0]}`/../config.sh

echo "::group::Pack toolchain"
    mkdir -p $ARTIFACT_PATH

    if [[ "$PACK_TOOLCHAIN" = 1 ]]; then
        if [[ "$HOST" == aarch64*-*-mingw* ]]; then
            # Reject directory-link cycles before dereferencing for Windows.
            find -L "$TOOLCHAIN_PATH" -type d -print > /dev/null
            tar chzf $ARTIFACT_PATH/$TOOLCHAIN_PACKAGE_NAME -C $TOOLCHAIN_PATH .
        else
            tar czf $ARTIFACT_PATH/$TOOLCHAIN_PACKAGE_NAME -C $TOOLCHAIN_PATH .
        fi
    else
        tar czf $ARTIFACT_PATH/$TOOLCHAIN_PACKAGE_NAME --files-from /dev/null
    fi

echo "::endgroup::"

echo 'Success!'
