bats_load_library "bats-support/load.bash"
bats_load_library "bats-assert/load.bash"
bats_load_library "bats-file/load.bash"
load "lib/uuu-helpers.bash"
load "lib/cp-helpers.bash"

setup_file() {
    uuu_setup
    sercap_setup || true
    uuu_load
}

teardown_file() {
    uuu_teardown
}

@test "cp: copy bytes within accessible memory" {
    run uuu_fb ucmd echo "== Copy bytes from RAM start to accessible RAM end."
    assert_success

    get_acc_ram_range || assert false

    run uuu_fb ucmd cp.b \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX))) \
	${SIZE_1MB_HEX}
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Reverse direction.
    run uuu_fb ucmd cp.b \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX))) \
	${ACC_RAM_START_HEX} \
	${SIZE_1MB_HEX}
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy bytes past RAM end" {
    run uuu_fb ucmd echo "== Copy bytes from RAM start to past RAM end."
    assert_success

    get_acc_ram_range || assert false

    # Destination range outside accessible RAM.
    run uuu_fb ucmd cp.b \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX + 1))) \
	${SIZE_1MB_HEX}
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Source range outside accessible RAM.
    run uuu_fb ucmd cp.b \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX + 1))) \
	${ACC_RAM_START_HEX} \
	${SIZE_1MB_HEX}
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy bytes below RAM start" {
    run uuu_fb ucmd echo "== Copy bytes from accessible RAM to below RAM start."
    assert_success

    get_acc_ram_range || assert false

    run uuu_fb ucmd cp.b \
	$(printf "0x%x" $((ACC_RAM_START_HEX + 0x1000))) \
	$(printf "0x%x" $((ACC_RAM_START_HEX - 1))) \
	0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Reverse direction.
    run uuu_fb ucmd cp.b \
	$(printf "0x%x" $((ACC_RAM_START_HEX - 1))) \
	$(printf "0x%x" $((ACC_RAM_START_HEX + 0x1000))) \
	0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy words within accessible memory" {
    run uuu_fb ucmd echo "== Copy words from RAM start to accessible RAM end."
    assert_success

    get_acc_ram_range || assert false

    run uuu_fb ucmd cp.w \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX))) \
	$(printf "0x%x" $((SIZE_1MB_HEX / WORD_SIZE)))
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Reverse direction.
    run uuu_fb ucmd cp.w \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX))) \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((SIZE_1MB_HEX / WORD_SIZE)))
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy words past RAM end" {
    run uuu_fb ucmd echo "== Copy words from RAM start to past RAM end."
    assert_success

    get_acc_ram_range || assert false

    # Destination range outside accessible RAM.
    run uuu_fb ucmd cp.w \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX + 1))) \
	$(printf "0x%x" $((SIZE_1MB_HEX / WORD_SIZE)))
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Source range outside accessible RAM.
    run uuu_fb ucmd cp.w \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX + 1))) \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((SIZE_1MB_HEX / WORD_SIZE)))
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy words below RAM start" {
    run uuu_fb ucmd echo "== Copy words from accessible RAM to below RAM start."
    assert_success

    get_acc_ram_range || assert false

    run uuu_fb ucmd cp.w \
	$(printf "0x%x" $((ACC_RAM_START_HEX + 0x1000))) \
	$(printf "0x%x" $((ACC_RAM_START_HEX - 1))) \
	0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Reverse direction.
    run uuu_fb ucmd cp.w \
	$(printf "0x%x" $((ACC_RAM_START_HEX - 1))) \
	$(printf "0x%x" $((ACC_RAM_START_HEX + 0x1000))) \
	0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy longs within accessible memory" {
    run uuu_fb ucmd echo "== Copy longs from RAM start to accessible RAM end."
    assert_success

    get_acc_ram_range || assert false

    run uuu_fb ucmd cp.l \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX))) \
	$(printf "0x%x" $((SIZE_1MB_HEX / LONG_SIZE)))
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Reverse direction.
    run uuu_fb ucmd cp.l \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX))) \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((SIZE_1MB_HEX / LONG_SIZE)))
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy longs past RAM end" {
    run uuu_fb ucmd echo "== Copy longs from RAM start to past RAM end."
    assert_success

    get_acc_ram_range || assert false

    # Destination range outside accessible RAM.
    run uuu_fb ucmd cp.l \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX + 1))) \
	$(printf "0x%x" $((SIZE_1MB_HEX / LONG_SIZE)))
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Source range outside accessible RAM.
    run uuu_fb ucmd cp.l \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX + 1))) \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((SIZE_1MB_HEX / LONG_SIZE)))
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy longs below RAM start" {
    run uuu_fb ucmd echo "== Copy longs from accessible RAM to below RAM start."
    assert_success

    get_acc_ram_range || assert false

    run uuu_fb ucmd cp.l \
	$(printf "0x%x" $((ACC_RAM_START_HEX + 0x1000))) \
	$(printf "0x%x" $((ACC_RAM_START_HEX - 1))) \
	0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Reverse direction.
    run uuu_fb ucmd cp.l \
	$(printf "0x%x" $((ACC_RAM_START_HEX - 1))) \
	$(printf "0x%x" $((ACC_RAM_START_HEX + 0x1000))) \
	0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy quads within accessible memory" {
    run uuu_fb ucmd echo "== Copy quads from RAM start to accessible RAM end."
    assert_success

    get_acc_ram_range || assert false

    run uuu_fb ucmd cp.q "${ACC_RAM_START_HEX}" "${ACC_RAM_START_HEX}" 1
    if [ "${status}" != "0" ]; then
        skip "quads copy not available"
    fi

    run uuu_fb ucmd cp.q \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX))) \
	$(printf "0x%x" $((SIZE_1MB_HEX / QUAD_SIZE)))
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Reverse direction.
    run uuu_fb ucmd cp.q \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX))) \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((SIZE_1MB_HEX / QUAD_SIZE)))
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy quads past RAM end" {
    run uuu_fb ucmd echo "== Copy quads from RAM start to past RAM end."
    assert_success

    get_acc_ram_range || assert false

    run uuu_fb ucmd cp.q "${ACC_RAM_START_HEX}" "${ACC_RAM_START_HEX}" 1
    if [ "${status}" != "0" ]; then
        skip "quads copy not available"
    fi

    # Destination range outside accessible RAM.
    run uuu_fb ucmd cp.q \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX + 1))) \
	$(printf "0x%x" $((SIZE_1MB_HEX / QUAD_SIZE)))
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Source range outside accessible RAM.
    run uuu_fb ucmd cp.q \
	$(printf "0x%x" $((ACC_RAM_START_HEX + ACC_RAM_SIZE_HEX - SIZE_1MB_HEX + 1))) \
	${ACC_RAM_START_HEX} \
	$(printf "0x%x" $((SIZE_1MB_HEX / QUAD_SIZE)))
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy quads below RAM start" {
    run uuu_fb ucmd echo "== Copy quads from accessible RAM to below RAM start."
    assert_success

    get_acc_ram_range || assert false

    run uuu_fb ucmd cp.q "${ACC_RAM_START_HEX}" "${ACC_RAM_START_HEX}" 1
    if [ "${status}" != "0" ]; then
        skip "quads copy not available"
    fi

    run uuu_fb ucmd cp.q \
	$(printf "0x%x" $((ACC_RAM_START_HEX + 0x1000))) \
	$(printf "0x%x" $((ACC_RAM_START_HEX - 1))) \
	0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"

    # Reverse direction.
    run uuu_fb ucmd cp.q \
	$(printf "0x%x" $((ACC_RAM_START_HEX - 1))) \
	$(printf "0x%x" $((ACC_RAM_START_HEX + 0x1000))) \
	0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}
