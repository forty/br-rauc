# RAUC variables
if test -z "${BOOT_ORDER}"; then
    # RAUC variables
    echo "> Setting up default RAUC variables"
    setenv BOOT_ORDER A B
    setenv BOOT_A_LEFT 3
    setenv BOOT_B_LEFT 3
    saveenv
fi

# Machine ID for systemd
if test -z "${MACHINE_ID}"; then
    echo "> Setting up random machine id"
    uuid MACHINE_ID
    saveenv
    echo "> Machine id is ${MACHINE_ID}"
fi

setenv rootfs
setenv kpart

for slot in "${BOOT_ORDER}"; do
  if test -n "${rootfs}"; then
    # skip remaining slots
  elif test "${slot}" = "A"; then
    if test ${BOOT_A_LEFT} -gt 0; then
      echo "> Found valid slot ${slot}, ${BOOT_A_LEFT} attempts remaining"
      setexpr BOOT_A_LEFT ${BOOT_A_LEFT} - 1
      setenv rootfs "PARTLABEL=${rootfs_A_label}"
      setenv kpart "#${rootfs_A_label}"
    fi
  elif test "${slot}" = "B"; then
    if test ${BOOT_B_LEFT} -gt 0; then
      echo "> Found valid slot ${slot}, ${BOOT_B_LEFT} attempts remaining"
      setexpr BOOT_B_LEFT ${BOOT_B_LEFT} - 1
      setenv rootfs "PARTLABEL=${rootfs_B_label}"
      setenv kpart "#${rootfs_B_label}"
    fi
  fi
done

echo "> Booting partition ${devtype} ${devnum}${kpart} (Linux rootfs = ${rootfs})"

if test -n "${rootfs}"; then
  setenv bootargs "root=${rootfs}" ro rootwait "systemd.machine_id=${MACHINE_ID}" "${bootargs_extra}"
  saveenv
else
  echo "> No valid slot found, resetting tries to 3"
  setenv BOOT_A_LEFT 3
  setenv BOOT_B_LEFT 3
  saveenv
  reset
fi

echo "> Loading Kernel..."
ext4load "${devtype}" "${devnum}${kpart}" "${kernel_addr_r}" "boot/${kernel_filename}"

echo "> Loading FDT..."
ext4load "${devtype}" "${devnum}${kpart}" "${fdt_addr_r}" "boot/${fdtfile}"

echo "> Booting System..."
bootz "${kernel_addr_r}" - "${fdt_addr_r}"
