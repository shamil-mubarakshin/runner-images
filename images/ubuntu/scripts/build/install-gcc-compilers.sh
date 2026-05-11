#!/bin/bash -e
################################################################################
##  File:  install-gcc-compilers.sh
##  Desc:  Install GNU C++ compilers
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

# DEBUG: edge repo persistence
echo "=== Check edge repo persistence 1 ==="
ls -la /etc/apt/sources.list.d
echo "============"
ls -la /etc/cron.daily

versions=$(get_toolset_value '.gcc.versions[]')

for version in ${versions[*]}; do
    echo "Installing $version..."
    apt-get install $version
done

# DEBUG: edge repo persistence
echo "=== Check edge repo persistence 2 ==="
ls -la /etc/apt/sources.list.d
echo "============"
ls -la /etc/cron.daily

invoke_tests "Tools" "gcc"
