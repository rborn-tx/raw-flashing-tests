#!/bin/bash

IMAGE_DIR=${1?Image directory must be passed}
IMAGE_DIR=$(realpath ${IMAGE_DIR})
SERCAP_CMD=${SERCAP_CMD-"nc localhost 2004"}
SERCAP_DIR=${SERCAP_DIR-"$(pwd)"}
SERCAP_VERBOSE=${SERCAP_VERBOSE-"0"}

BATS_ARGS=${BATS_ARGS-"--timing --report-formatter junit --output reports/"}
if [ "${BATS_VERBOSE}" = "1" ]; then
    BATS_ARGS="${BATS_ARGS} --show-output-of-passing-tests --verbose-run"
fi

bash -c "\
  BATS_LIB_PATH='$(pwd)/bats' \
  IMAGE_DIR='${IMAGE_DIR}' \
  SERCAP_CMD='${SERCAP_CMD}' \
  SERCAP_DIR='${SERCAP_DIR}' \
  bats/bats-core/bin/bats ${BATS_ARGS} tests/fastboot.bats tests/cp.bats"
