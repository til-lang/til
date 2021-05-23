#!/bin/bash

# TODO: transcribe this script to Til, someday. :)

if [[ $1 == "" ]];then
    version=release
else
    version=$1
fi

export LD_LIBRARY_PATH=$PWD

for file in examples/*.til;do
    echo "=== $file ==="
    if [[ $file == "examples/unhandled-error.til" ]];then
        ./til.$version $file && break
        continue
    elif [[ $file == "examples/shared-library.til" ]];then
        echo "Skipping $file"
        continue
    fi
    if ! ./til.$version $file;then
        code=$?
        echo "$file : ERROR $code"
        exit $code
    fi
done

echo -e "\nSUCCESS"
