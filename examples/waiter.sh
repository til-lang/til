#!/bin/bash

i=0
while (( $i < 10 ));do
    echo $i
    i=$(( $i + 1 ))
    sleep 0.25
done
