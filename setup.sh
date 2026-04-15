#!/bin/bash

CLEAN_INSTALL=${CLEAN_INSTALL:-0}

clone_bats_repo() {
    local DIR="$1/$2"
    local REPO="$2"
    local VERSION="$3"
    echo "Installing ${REPO} ${VERSION}..."
    if ! git clone --depth=1 "https://github.com/bats-core/${REPO}.git" -b "${VERSION}" "${DIR}" >/dev/null 2>&-; then
        return 1
    fi
}

install_bats() {
    local DIR="$1/bats"
    local REPO=""
    local NAME=""
    local VERSION=""

    if [ "${CLEAN_INSTALL}" -eq 1 ]; then
        rm -Rf "${DIR}"
    fi

    for REPO in bats-core:v1.12.0 bats-assert:v2.1.0 bats-file:v0.4.0 bats-support:v0.3.0; do
        NAME=$(echo ${REPO} | cut -d':' -f 1)
        VERSION=$(echo ${REPO} | cut -d':' -f 2)
        if [ -d "${DIR}/${NAME}" ]; then
            echo "Local repository for ${NAME} already exists; not cloning it."
            continue
        fi
        if ! clone_bats_repo "${DIR}" "${NAME}" "${VERSION}"; then
            echo "Error: could not clone ${NAME} repository!"
            return 1
        fi
    done
}

if [ ! -d bats/ ]; then
    echo "Directory bats/ not found; aborting." >&2
    exit 1
fi

install_bats .
