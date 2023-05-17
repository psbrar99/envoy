#!/bin/bash

set -eu

ClangV=12
curl -sLO https://github.com/llvm/llvm-project/releases/download/llvmorg-12.0.0/clang+llvm-12.0.0-aarch64-linux-gnu.tar.xz
tar -xvf clang+llvm-12.0.0-aarch64-linux-gnu.tar.xz
export HOME="$PWD"
printf "set(CMAKE_C_COMPILER \"clang\")\nset(CMAKE_CXX_COMPILER \"clang++\")\n" > ${HOME}/toolchain
export PATH="$PWD/clang+llvm-12.0.0-aarch64-linux-gnu/bin:$PATH"

NinjaV=1.10.2
NinjaH=ce35865411f0490368a8fc383f29071de6690cbadc27704734978221f25e2bed

wget https://github.com/ninja-build/ninja/archive/refs/tags/v$NinjaV.tar.gz
echo "$NinjaH v$NinjaV.tar.gz" >sha && sha256sum -c sha
tar -xzf v$NinjaV.tar.gz
cd ninja-$NinjaV
CC=clang-$ClangV CXX=clang++ ./configure.py --bootstrap
mv ninja /usr/local/bin/

cd ..
GoV=1.16.5
GoHarm64=d5446b46ef6f36fdffa852f73dfbbe78c1ddf010b99fa4964944b9ae8b4d6799
GOARCH=arm64
wget https://golang.org/dl/go$GoV.linux-$GOARCH.tar.gz
tar -C /usr/local -xzf go$GoV.linux-$GOARCH.tar.gz

export GOROOT=/usr/local/go
export PATH="$GOROOT/bin:$PATH"

BoringV=853ca1ea1168dff08011e5d42d94609cc0ca2e27
wget https://commondatastorage.googleapis.com/chromium-boringssl-fips/boringssl-$BoringV.tar.xz && tar -xf boringssl-853ca1ea1168dff08011e5d42d94609cc0ca2e27.tar.xz
cd boringssl
perl -p -i -e 's/defined.*ELF.*defined.*GNUC.*/$0 \&\& !defined(GOBORING)/' crypto/mem.c

printf "set(CMAKE_C_COMPILER \"clang\")\nset(CMAKE_CXX_COMPILER \"clang++\")\n" >${HOME}/toolchain
rm -rf build
mkdir build && cd build && cmake -GNinja -DCMAKE_TOOLCHAIN_FILE=${HOME}/toolchain -DFIPS=1 -DCMAKE_BUILD_TYPE=Release ..
ninja
ninja run_tests
./crypto/crypto_test
# Verify correctness of the FIPS build.
if [[ `tool/bssl isfips` != "1" ]]; then
  echo "ERROR: BoringSSL tool didn't report FIPS build."
  exit 1
fi
