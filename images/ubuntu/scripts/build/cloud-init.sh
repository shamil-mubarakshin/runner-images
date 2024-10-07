#!/bin/bash

if ! cloud-init status --wait --long; then
    echo CLOUD_INIT_FAILED
fi
