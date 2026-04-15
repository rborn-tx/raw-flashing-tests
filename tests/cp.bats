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

@test "cp: copy bytes within accessible memory" {
    run uuu_fb ucmd echo "Copy bytes from RAM start to accessible RAM end (offset 1G-64M)."
    assert_success

    run uuu_fb ucmd cp.b 0x40000000 0x7bf00000 0x100000
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy bytes past RAM end" {
    run uuu_fb ucmd echo "Copy bytes from RAM start to past RAM end."
    assert_success
    run uuu_fb ucmd cp.b 0x40000000 0x7bf00000 0x100001
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy bytes below RAM start" {
    run uuu_fb ucmd echo "Copy bytes from accessible RAM to below RAM start."
    assert_success
    run uuu_fb ucmd cp.b 0x44000000 0x3fffffff 0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy words within accessible memory" {
    run uuu_fb ucmd echo "Copy words from RAM start to accessible RAM end."
    assert_success
    run uuu_fb ucmd cp.w 0x40000000 0x7bf00000 0x80000
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy words past RAM end" {
    run uuu_fb ucmd echo "Copy words from RAM start to past RAM end."
    assert_success
    run uuu_fb ucmd cp.w 0x40000000 0x7bf00000 0x80001
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy words below RAM start" {
    run uuu_fb ucmd echo "Copy words from accessible RAM to below RAM start."
    assert_success
    run uuu_fb ucmd cp.w 0x44000000 0x3ffffffe 0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy longs within accessible memory" {
    run uuu_fb ucmd echo "Copy longs from RAM start to accessible RAM end."
    assert_success
    run uuu_fb ucmd cp.l 0x40000000 0x7bf00000 0x40000
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy longs past RAM end" {
    run uuu_fb ucmd echo "Copy longs from RAM start to past RAM end."
    assert_success
    run uuu_fb ucmd cp.l 0x40000000 0x7bf00000 0x40001
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy longs below RAM start" {
    run uuu_fb ucmd echo "Copy longs from accessible RAM to below RAM start."
    assert_success
    run uuu_fb ucmd cp.w 0x44000000 0x3ffffffc 0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy quads within accessible memory" {
    run uuu_fb ucmd echo "Copy quads from RAM start to accessible RAM end."
    assert_success
    run uuu_fb ucmd cp.q 0x40000000 0x7bf00000 0x20000
    assert_success
    [ -z "${SERCAP_CMD}" ] || \
	refute_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy quads past RAM end" {
    run uuu_fb ucmd echo "Copy quads from RAM start to past RAM end."
    assert_success
    run uuu_fb ucmd cp.q 0x40000000 0x7bf00000 0x20001
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}

@test "cp: copy quads below RAM start" {
    run uuu_fb ucmd echo "Copy quads from accessible RAM to below RAM start."
    assert_success
    run uuu_fb ucmd cp.w 0x44000000 0x3ffffff8 0x1
    assert_failure 255
    [ -z "${SERCAP_CMD}" ] || \
	assert_output --regexp "## ERROR: Loading data.*forbidden by the hardening feature"
}
