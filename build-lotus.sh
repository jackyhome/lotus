#!/usr/bin/env bash
 export RUSTFLAGS="-C target-cpu=native -g"
 export FFI_BUILD_FROM_SOURCE=1
 export GOPROXY=https://goproxy.cn

 make clean all
