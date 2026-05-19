bats_load_library "bats-support/load.bash"
bats_load_library "bats-assert/load.bash"
bats_load_library "bats-file/load.bash"
load "lib/uuu-helpers.bash"

setup_file() {
    uuu_setup
    sercap_setup || true
    uuu_load
}

teardown_file() {
    uuu_teardown
}

@test "fb-buf: check fastboot buffer address protection" {
    if [ -z "${SERCAP_CMD}" ]; then
        skip "serial capture not enabled"
    fi

    # TODO: Add more tests.
    # TODO: Use functions from cp-helpers.bash.
    # Failure case: below RAM start.
    # Good case: right above RAM start.
    # Failure case: above 1G-64M.
    # Good case: right below 1G-64M-112M (FB buffer size).
    # Fail case: right above 1G-64M-112M (FB buffer size).

    # If we can get the RAM address via "bdinfo", use it in the tests.
    run uuu_fb ucmd bdinfo

    if [ "${status}" = "0" ]; then
        local ramstart
        ramstart=$(echo "${output}" \
                       | sed -ne '/DRAM bank[[:space:]]*= 0x0*0000[[:space:]]*$/ { N;N;p; }' \
                       | sed -ne 's/^.*start.*= \(0x[0-9a-fA-F]\+\)[[:space:]]*$/\1/p')
        if [ -z "${ramstart}" ]; then
            assert false
        fi

        # NOTE: all fastboot commands will fail because fastboot is already running, but the address
        # will still be set despite the error.

        # Attempt to put buffer below ram start.
        local addr1
        addr1=$(printf "0x%x" $((ramstart - 0x10000)))
        run uuu_fb ucmd fastboot -l "${addr1}" -s 0x20000 usb 0
        assert_failure
        assert_output \
            --regexp "## ERROR: Loading data into addr.*forbidden by the hardening feature"
        assert_output \
            --partial "## WARNING: Resetting Fastboot buffer address/size to default"

        # Attempt to put buffer above ram start + 1GB.
        local addr2
        addr2=$(printf "0x%x" $((ramstart + 1024*1024*1024)))
        run uuu_fb ucmd fastboot -l "${addr2}" -s 0x20000 usb 0
        assert_failure
        assert_output \
            --regexp "## ERROR: Loading data into addr.*forbidden by the hardening feature"
        assert_output \
            --partial "## WARNING: Resetting Fastboot buffer address/size to default"

        # Attempt to put buffer at ram start + 64k.
        local addr3
        addr3=$(printf "0x%x" $((ramstart + 64*1024)))
        run uuu_fb ucmd fastboot -l "${addr3}" -s 0x20000 usb 0
        assert_failure
        refute_output \
            --regexp "## ERROR: Loading data into addr.*forbidden by the hardening feature"
        refute_output \
            --partial "## WARNING: Resetting Fastboot buffer address/size to default"
    else
        # Send the fastboot command (via fastboot) changing buffer address to invalid fixed address.
        run uuu_fb ucmd fastboot -l 0x00100000 -s 0x10000 usb 0
        assert_failure
        assert_output \
            --regexp "## ERROR: Loading data into addr.*forbidden by the hardening feature"
        assert_output \
            --partial "## WARNING: Resetting Fastboot buffer address/size to default"
    fi

    # Return buffer to default address.
    run uuu_fb ucmd fastboot usb 0
    assert_failure
}

# TODO: IMPLEMENT
@test "fb-buf: check fastboot buffer address protection (downstream)" {
    # Downstream case has the variable "fastboot_buffer" that allows arbritrary
    # setting the buffer address; changes to the address take place right after
    # every ucmd/acmd execution.
    :
}

@test "fb-cmd: check getvar command via UUU" {
    run uuu_fb ucmd echo "== Checking getvar command via UUU"
    assert_success
    run uuu_fb getvar "version-bootloader"
    assert_success
    assert_output --partial "U-Boot "
}

@test "fb-cmd: check getvar command via standard fastboot" {
    run uuu_fb ucmd echo "== Checking getvar command via standard fastboot"
    assert_success
    run std_fb getvar "version-bootloader"
    assert_success
    assert_output --partial "U-Boot "
}

@test "fb-cmd: check download command" {
    if [ -z "${SERCAP_CMD}" ]; then
        skip "serial capture not enabled"
    fi

    run uuu_fb ucmd echo "== Checking download command"
    assert_success

    # Determine the address of the fastboot buffer; note: help returns failure.
    run uuu_fb ucmd help fastboot
    assert_failure
    assert_output --partial "address of buffer"
    assert_output --partial "size of buffer"
    local bufaddr
    local bufsize
    bufaddr=$(echo "${output}" | \
                  sed -ne 's#^.*address of buffer.*transfers (\(0x[0-9a-fA-F]\+\)).*#\1#p')
    bufsize=$(echo "${output}" | \
                  sed -ne 's#^.*size of buffer.*transfers (\(0x[0-9a-fA-F]\+\)).*#\1#p')
    #echo "bufaddr=[${bufaddr}]" >&3
    #echo "envsize=[${envsize}]" >&3
    assert [ -n "${bufaddr}" ]
    assert [ -n "${bufsize}" ]

    # Create an environment file, download and import it to check if the download was okay.
    local imgdir="${IMAGE_DIR?IMAGE_DIR must be set}"
    local tmpenvfile
    tmpenvfile=$(TMPDIR="${imgdir}" mktemp -t u-boot-env-XXXXXX.tmp)
    cat <<EOF >"${tmpenvfile}"
dummy1=contents1
dummy2=contents2
dummy3=contents3
dummy4=contents4
EOF
    local envsize
    envsize=$(stat -c "%s" "${tmpenvfile}")

    run uuu_fb ucmd echo "== About to run download command."
    assert_success
    assert_output --partial "About to run download command"

    run uuu_fb download -f "../$(basename "${tmpenvfile}")"
    assert_success
    rm -f "${tmpenvfile}"

    run uuu_fb ucmd env import -t "${bufaddr}" "${envsize}"
    assert_success
    # shellcheck disable=SC2016
    run uuu_fb ucmd 'test "$dummy1" = "contents1"'
    assert_success

    # shellcheck disable=SC2016
    run uuu_fb ucmd 'test "$dummy4" = "contents4"'
    assert_success

    # shellcheck disable=SC2016
    run uuu_fb ucmd 'test "$dummy5" = "contents5"'
    assert_failure
}

@test "fb-cmd: erase and flash user partition" {
    run uuu_fb ucmd echo "== Checking presence of required variables"
    assert_success
    run uuu_fb ucmd 'test -n "${fastboot_partition_alias_all}"'
    assert_success
    run uuu_fb ucmd 'test -n "${fastboot_partition_alias_bootloader}${fastboot_raw_partition_bootloader}"'
    assert_success
    run uuu_fb ucmd 'test -n "${emmc_dev}"'
    assert_success
    run uuu_fb ucmd 'test -n "${emmc_ack}"'
    assert_success

    run uuu_fb ucmd echo "== Checking user partition erasing"
    assert_success
    run uuu_fb -t 90000 erase all
    assert_success

    # ---
    # Generate a disk image:
    # ---
    local diskimg="${IMAGE_DIR}/image.tmp/disk.img"
    rm -fr "${diskimg%/*}"
    mkdir  "${diskimg%/*}"
    truncate -s 81M "${diskimg}"

    local MB=$((1024 * 1024 / 512))

    sfdisk "${diskimg}" <<EOF
label: dos
unit: sectors
1 : start=1, size=$((20 * MB)), type=83
2 : start=$((1 + 20 * MB)), size=$((20 * MB)), type=82
3 : start=$((1 + 40 * MB)), size=$((20 * MB)), type=0c
4 : start=$((1 + 60 * MB)), size=$((20 * MB)), type=c1
EOF

    # ---
    # Flash disk image:
    # ---
    run uuu_fb flash -raw2sparse all "../image.tmp/disk.img"
    assert_success
    rm -fr "${diskimg%/*}"

    # ---
    # Ensure disk image is understood by U-Boot:
    # ---
    if [ -n "${SERCAP_CMD}" ]; then
	# Determine eMMC device.
	local emmcdev
	run uuu_fb ucmd 'mmc list'
	assert_success
	emmcdev=$(echo "${output}" | sed -ne 's/^.* \([0-9]\) (eMMC).*/\1/p')
	assert [ -n "${emmcdev}" ]

	# List partitions in the eMMC.
	run uuu_fb ucmd "mmc dev ${emmcdev}"
	assert_success
	run uuu_fb ucmd 'mmc part'
	assert_success

	# Expected output from U-Boot:
	#
	# Part    Start Sector    Num Sectors     UUID            Type
	#   1     1               40960           0610a0f2-01     83
	#   2     40961           40960           0610a0f2-02     82
	#   3     81921           40960           0610a0f2-03     0c
	#   4     122881          40960           0610a0f2-04     c1

	# Check partition types against expectations.
	local part partnum partype partype_
	for part in "1:83" "2:82" "3:0c" "4:c1"; do
	    partnum=${part%:*}
	    partype=${part#*:}
	    partype_=$(echo "${output}" \
			  | sed -ne '/part.*start.*num.*type/I,$ p' \
			  | sed -ne "$((partnum+1))"'{s/^[[:space:]]*//; s/[[:space:]]\+/;/g; p}' \
			  | cut -d';' -f5)
	    assert [ "${partype}" = "${partype_}" ]
	done
    fi
}

@test "fb-cmd: erase boot partitions" {
    run uuu_fb ucmd echo "== Checking presence of required variables"
    assert_success
    run uuu_fb ucmd 'test -n "${fastboot_partition_alias_all}"'
    assert_success
    run uuu_fb ucmd 'test -n "${fastboot_partition_alias_bootloader}${fastboot_raw_partition_bootloader}"'
    assert_success
    run uuu_fb ucmd 'test -n "${emmc_dev}"'
    assert_success
    run uuu_fb ucmd 'test -n "${emmc_ack}"'
    assert_success

    run uuu_fb ucmd echo "=="; echo "== Erasing 1st boot partition partially"; echo "=="
    run uuu_fb ucmd 'mmc dev "${emmc_dev}" 1 && mmc erase 0 200'
    assert_success

    run uuu_fb ucmd echo "=="; echo "== Erasing 2nd boot partition partially"; echo "=="
    run uuu_fb ucmd 'mmc dev "${emmc_dev}" 2 && mmc erase 0 200'
    assert_success
}

@test "fb-cmd: check boot command" {
    run uuu_fb ucmd echo "== Checking boot command"
    assert_success

    run uuu_fb boot
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
        assert_output --partial "command boot not recognized"
}

@test "fb-cmd: check reboot commands" {
    run uuu_fb ucmd echo "== Checking reboot commands"
    assert_success

    # NOTE: UUU does not have support for sending any reboot commands besides "reboot".
    # local cmd_list="reboot reboot-bootloader reboot-fastboot reboot-recovery"
    local cmd_list="reboot"

    for cmd in ${cmd_list}; do
        run uuu_fb ucmd echo "** About to ${cmd} reboot command."
        assert_success

        run uuu_fb ${cmd}
        assert_failure 255
        [ -z "${SERCAP_CMD}" ] || \
            assert_output --partial "command ${cmd} not recognized"
    done
}

@test "fb-cmd: check set_active command" {
    run uuu_fb ucmd echo "== Checking set_active command"
    assert_success

    run uuu_fb set_active
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
        assert_output --partial "command set_active not recognized"
}

@test "fb-cmd: check oem format command" {
    run uuu_fb ucmd echo "== Checking oem format command"
    assert_success

    run uuu_fb oem format
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
        assert_output --partial "command oem format not recognized"
}

@test "fb-cmd: check oem partconf command" {
    run uuu_fb ucmd echo "== Checking oem partconf command"
    assert_success

    local boot_ack="1"
    local boot_part="1"
    run uuu_fb oem partconf "${boot_ack}" "${boot_part}"
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
        assert_output --regexp "command oem partconf.* not recognized"
}

@test "fb-cmd: check oem bootbus command" {
    run uuu_fb ucmd echo "== Checking oem bootbus command"
    assert_success

    # Equivalent to:
    # mmc bootbus <dev> <boot_bus_width> <reset_boot_bus_width> <boot_mode>
    #                   |            set via oem bootbus                  |
    #                   +-------------------------------------------------+
    local boot_bus_width="0"
    local reset_boot_bus_width="0"
    local boot_mode="0"
    run uuu_fb oem bootbus "${boot_bus_width}" "${reset_boot_bus_width}" "${boot_mode}"
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
        assert_output --regexp "command oem bootbus.* not recognized"
}

@test "fb-cmd: check oem run command" {
    run uuu_fb ucmd echo "== Checking oem run command"
    assert_success

    run uuu_fb oem run echo "hello"
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
        assert_output --regexp "command oem run.* not recognized"
}

@test "fb-cmd: check oem console command" {
    run uuu_fb ucmd echo "== Checking oem console command"
    assert_success

    run uuu_fb oem console "some data into the console"
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
        assert_output --regexp "command oem console.* not recognized"
}

@test "fb-cmd: check oem board command" {
    run uuu_fb ucmd echo "== Checking oem board command"
    assert_success

    run uuu_fb oem board "arguments to oem board"
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
        assert_output --regexp "command oem board.* not recognized"
}

@test "fb-cmd: check echo via acmd" {
    run uuu_fb ucmd echo "== Checking acmd command"
    assert_success
}

# NOTE: THIS MUST BE THE LAST COMMAND SINCE IT LEAVES FASTBOOT MODE
@test "fb-cmd: check continue command" {
    run uuu_fb ucmd echo "== Checking continue command"
    assert_success

    run uuu_fb continue
    assert_success
    if [ -n "${SERCAP_CMD}" ]; then
        # Check if the last line contains the U-Boot prompt:
	local lastline
        lastline=$(echo "${output}" | tail -1)
        if echo "${lastline}" | grep -qE -e '^[A-Za-z0-8 ]+# *$'; then
            assert true
        else
            assert false "Prompt not found; last line was: \"${lastline}\""
        fi
    fi
}
