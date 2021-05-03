#!/bin/bash

# TODO: transcribe this script to Til, someday. :)

export LD_LIBRARY_PATH=$PWD

for file in examples/*.til;do
    echo "=== $file ==="
    if [[ $file == "examples/unhandled-error.til" ]];then
        ./til.release $file && break
        continue
    fi
    ./til.release $file || break
done
