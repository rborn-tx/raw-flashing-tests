#!/bin/bash

# Environment variables:
#
# - IMAGE_DIR (required): Directory containing TEZI image under test.
# - SERCAP_CMD (optional): Command that will be started/stopped to capture
#   the U-Boot serial console output.
# - SERCAP_DIR (optional): Directory where to store the logs for the U-Boot
#   serial console.
#
# Example:
#   SERCAP_CMD="nc localhost 2004"
#       with port 2004 on the local host being a "ser2net" connection attached
#       to the serial port where U-Boot is expected to send its console output.
#

SERCAP_CMD=${SERCAP_CMD-""}
SERCAP_DIR=${SERCAP_DIR-""}
SERCAP_VERBOSE=${SERCAP_VERBOSE-"0"}

# Note: For things to work the UUU verbose flag must be specified.
UUU_FLAGS=${UUU_FLAGS-"-v"}
UUU_QUIET=${UUU_QUIET:-"1"}

# Flags passed to the fastboot command.
FASTBOOT_FLAGS=${FASTBOOT_FLAGS-"-v"}
FASTBOOT_CMD=$(which fastboot)


# TODO: Determine VID/PID from image.
VID=0x1b67
PID=0x4000

# Set up the serial capture if variable SERCAP_CMD is set. When that variable is
# set, the directory for storing the serial capture logs as defined by variable
# SERCAP_DIR must also exist.
#
sercap_setup() {
    if [ -z "${SERCAP_CMD}" ]; then
        # Capture is disabled.
        return 1
    fi
    if [ -z "${SERCAP_DIR}" ] || [ ! -d "${SERCAP_DIR}" ]; then
        echo "## ERROR: Serial capture directory is not defined." >&3
        return 1
    fi

    install -m 644 \
            -o "$(stat -c "%U" "${SERCAP_DIR}")" \
            -g "$(stat -c "%G" "${SERCAP_DIR}")" \
            /dev/null \
            "${SERCAP_DIR}/sercap.log"
}

# Start the serial capture process saving its PID into variable SERCAP_PID.
#
sercap_start() {
    if [ -z "${SERCAP_CMD}" ] || \
       [ -z "${SERCAP_DIR}" ] || [ ! -d "${SERCAP_DIR}" ]; then
        return 0
    fi

    install -m 644 \
            -o "$(stat -c "%U" "${SERCAP_DIR}")" \
            -g "$(stat -c "%G" "${SERCAP_DIR}")" \
            /dev/null \
            "${SERCAP_DIR}/sercap-last.log"
    echo "sercap: starting capture"
    ${SERCAP_CMD} > "${SERCAP_DIR}/sercap-last.log" 2>&1 &
    SERCAP_PID=$!
}

# Stop the serial capture process and wait for it to finish. Also dump its
# output to stdout.
#
sercap_stop() {
    if [ -z "${SERCAP_CMD}" ] || [ -z "${SERCAP_PID}" ] || \
       [ -z "${SERCAP_DIR}" ] || [ ! -d "${SERCAP_DIR}" ]; then
        return 0
    fi

    # Give some time for receiving the serial data.
    sleep 1

    echo "sercap: waiting capture to stop"
    kill "${SERCAP_PID}"
    wait "${SERCAP_PID}" || true
    SERCAP_PID=""

    if [ "${SERCAP_VERBOSE}" = "1" ]; then
        cat "${SERCAP_DIR}/sercap-last.log" >&3
    fi
    cat "${SERCAP_DIR}/sercap-last.log" 2>&1
    cat "${SERCAP_DIR}/sercap-last.log" >> \
        "${SERCAP_DIR}/sercap.log" 2>/dev/null
}

# Helper to run UUU (must be run in the TEZI image directory)
_uuu_run() {
    local dir_ out_ res_
    dir_=${1?Directory required}
    # shellcheck disable=SC2086
    out_=$(./recovery/uuu ${UUU_FLAGS} "${dir_}" 2>&1)
    res_=$?
    # UUU outputs ANSI escape sequences: drop them
    out_=$(echo "${out_}" | sed -Ee 's/\x1B\[[0-9;]*[A-Za-z]//g')
    # Drop the block listing PID/VID to make output less noisy:
    if [ "${UUU_QUIET}" = "1" ]; then
        out_=$(echo "${out_}" | \
                   sed -e '/uuu.*Universal Update Utility/,/Wait for Known USB Device/c\UUU_HEADER')
    fi
    echo "${out_}"
    return ${res_}
}

_uuu_load() {
    local res="0"
    # Run UUU in the image directory.
    (
        cd "${IMAGE_DIR}"
        mkdir -p generated.tmp/
        cat <<EOF >generated.tmp/uuu.auto
uuu_version 1.5.165
SDPS: boot -f ../imx-boot-recoverytezi
SDPS: done
EOF
        _uuu_run generated.tmp/

    ) || res=$?

    rm -fr "${IMAGE_DIR}/generated.tmp"
    echo "UUU:LOAD:STATUS: ${res}"

    return ${res}
}

_uuu_fb() {
    local toutstr=""
    if [ "$1" = "-t" ]; then
        toutstr="[-t ${2?timeout in ms must be passed}]"
        shift 2
    fi
    local res="0"
    # Run UUU in the image directory.
    (
        cd "${IMAGE_DIR}"
        mkdir -p generated.tmp/
        cat <<EOF >generated.tmp/uuu.auto
uuu_version 1.5.165
CFG: FB: -vid ${VID} -pid ${PID}
FB${toutstr}: $*
FB: done
EOF
        _uuu_run generated.tmp/

    ) || res=$?

    rm -fr "${IMAGE_DIR}/generated.tmp"
    echo "UUU:FB:COMMAND: $*"
    echo "UUU:FB:STATUS: ${res}"

    return ${res}
}

uuu_setup() {
    if [ -z "${IMAGE_DIR}" ]; then
        echo "IMAGE_DIR is not set." >&2
        return 1
    fi

    if [ "$(id -u)" != "0" ]; then
        echo "Tests must be run as root." >&2
        return 1
    fi
}

uuu_teardown() {
    rm -fr "${IMAGE_DIR}/generated"
}

uuu_load() {
    {
        if [ -n "${SERCAP_CMD}" ]; then
            echo "** Running with U-Boot console capture enabled."
            echo "** Capture command: \"${SERCAP_CMD}\""
            echo "** Capture directory: \"${SERCAP_DIR}\""
        else
            echo "** Running with U-Boot console capture DISABLED."
        fi
        echo ""
        echo "** Please put device into recovery mode."
    } >&3

    sercap_start
    _uuu_load "$@"
    local res=$?
    sercap_stop

    echo "" >&3

    return ${res}
}

# Send Fastboot command through UUU possibly colleting U-Boot console output.
#
# Usage: uuu_fb [-t <timeout-ms>] cmd...
#
uuu_fb() {
    sercap_start
    _uuu_fb "$@"
    local res=$?
    sercap_stop
    return ${res}
}

_std_fb() {
    if [ -z "${FASTBOOT_CMD}" ]; then
	echo "## ERROR: _std_fb called with fastboot command not available" >&3
	return 1
    fi

    local res="0"
    # Run "fastboot" in the image directory.
    (
        cd "${IMAGE_DIR}"
        # shellcheck disable=SC2086
        ${FASTBOOT_CMD} ${FASTBOOT_FLAGS} "$@"
    ) || res=$?

    echo "STD:FB:COMMAND: $*"
    echo "STD:FB:STATUS: ${res}"

    return ${res}
}

# Send Fastboot command through command "fastboot" possibly colleting U-Boot
# console output.
#
# Usage: uuu_fb [-t <timeout-ms>] cmd...
#
std_fb() {
    sercap_start
    _std_fb "$@"
    local res=$?
    sercap_stop
    return ${res}
}
