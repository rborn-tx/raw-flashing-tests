#!/bin/bash

# Actual RAM start/size:
RAM_START_HEX=""
RAM_SIZE_HEX=""

# Accessible RAM start/size (from the perspective of self-overwrite protection)
ACC_RAM_START_HEX=""
ACC_RAM_SIZE_HEX=""

# Constants:
SIZE_1MB_HEX="0x100000"
WORD_SIZE="2"
LONG_SIZE="4"
QUAD_SIZE="8"

# get_ram_range: Determine RAM start and size from "bdinfo" output.
get_ram_range() {
    if [ -n "${RAM_START_HEX}" ]; then
	# Already set.
	return 0
    fi

    run uuu_fb ucmd bdinfo
    if [ "${status}" = "0" ]; then
        local ramstart ramsize
        ramstart=$(echo "${output}" \
                       | sed -ne '/DRAM bank[[:space:]]*= 0x0*0000[[:space:]]*$/ { N;N;p; }' \
                       | sed -ne 's/^.*start.*= \(0x[0-9a-fA-F]\+\)[[:space:]]*$/\1/p')
        ramsize=$(echo "${output}" \
                      | sed -ne '/DRAM bank[[:space:]]*= 0x0*0000[[:space:]]*$/ { N;N;p; }' \
                      | sed -ne 's/^.*size.*= \(0x[0-9a-fA-F]\+\)[[:space:]]*$/\1/p')
        if [ -z "${ramstart}" ] || [ -z "${ramsize}" ]; then
            return 1
        fi

	RAM_START_HEX="${ramstart}"
	RAM_SIZE_HEX="${ramsize}"
    fi
}

get_acc_ram_range() {
    get_ram_range || return 1

    ACC_RAM_START_HEX=${RAM_START_HEX}
    if ((RAM_SIZE_HEX >= 1024*1024*1024)); then
	ACC_RAM_SIZE_HEX=$(printf "0x%x" $(( 1024*1024*1024 - 64*1024*1024 )))
    else
	ACC_RAM_SIZE_HEX=$(printf "0x%x" $(( RAM_SIZE_HEX - 64*1024*1024 )))
    fi
}
