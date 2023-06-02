#! /usr/bin/env sh

set -e
forge coverage --report lcov -o ./lcov1.info
lcov --remove ./lcov.info -o ./lcov.info 'script/*' 'test/*' 'layerzero/*' 
genhtml lcov.info -o coverage