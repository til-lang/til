#!/bin/bash

# TODO: transcribe this script to Til, someday. :)

if [[ $1 == "" ]];then
    if [ -e "til.release" ];then
        version=release
    else
        version=debug
    fi
else
    version=$1
fi

source bin/settings.sh

results=""

for file in examples/*.til;do
    echo "=== $file ==="
    if [[ $file == "examples/unhandled-error.til" ]];then
        ./til.$version $file && break
        continue
    elif [[ $file == "examples/shared-library.til" || $file == "examples/exit-with-code.til" ]];then
        echo "Skipping $file"
        continue
    fi
    if ! echo "some input, just in case" | ./til.$version $file;then
        code=$?
        results="$results\n$file : \033[31mERROR $code\033[39m"
    else
        results="$results\n$file : \033[32mOK\033[39m"
    fi
done

echo -e "Results:$results"
