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

# Find the root file systems (A and B)
# This will set the following env variables:
# - rootfs_A kernel_devtype_A kernel_devnum_A kernel_part_A
# - rootfs_B kernel_devtype_B kernel_devnum_B kernel_part_B
if test -z "${rootfs_A}" -o -z "${rootfs_B}"; then
    echo "> Detecting rootfs partitions"
    for kdevtype in mmc; do
      for kdevnum in 0 1; do
        kpartitions=
        part list "${kdevtype}" "${kdevnum}" kpartitions
        for kpartition in ${kpartitions}; do
          echo "> Trying ${kdevtype} ${kdevnum}:${kpartition}"
          fsuuid=notfound
          fsuuid "${kdevtype}" "${kdevnum}:${kpartition}" fsuuid
          if test -z "${rootfs_A}" -a "${fsuuid}" = "${rootfs_A_uuid}"; then
             part list "${kdevtype}" "${kdevnum}"
             part uuid "${kdevtype}" "${kdevnum}:${kpartition}" partuuid
             echo "> Rootfs A found! PARTUUID=${partuuid}"
             setenv rootfs_A "PARTUUID=${partuuid}"
             setenv kernel_devtype_A "${kdevtype}"
             setenv kernel_devnum_A "${kdevnum}"
             setenv kernel_part_A "${kpartition}"
             saveenv
          fi
          if test -z "${rootfs_B}" -a "${fsuuid}" = "${rootfs_B_uuid}"; then
             part list "${kdevtype}" "${kdevnum}"
             part uuid "${kdevtype}" "${kdevnum}:${kpartition}" partuuid
             echo "> Rootfs B found! PARTUUID=${partuuid}"
             setenv rootfs_B "PARTUUID=${partuuid}"
             setenv kernel_devtype_B "${kdevtype}"
             setenv kernel_devnum_B "${kdevnum}"
             setenv kernel_part_B "${kpartition}"
             saveenv
          fi
        done
      done
    done
    echo "> Finished detecting rootfs partitions"
fi

echo "> Partition rootfs A is on ${kernel_devtype_A} ${kernel_devnum_A}:${kernel_part_A} (Linux rootfs = ${rootfs_A})"
echo "> Partition rootfs B is on ${kernel_devtype_B} ${kernel_devnum_B}:${kernel_part_B} (Linux rootfs = ${rootfs_B})"

# TODO check all is good at this point

setenv rootfs
setenv kdevtype
setenv kdevnum
setenv kpart

for slot in "${BOOT_ORDER}"; do
  if test -n "${rootfs}"; then
    # skip remaining slots
  elif test "${slot}" = "A"; then
    if test ${BOOT_A_LEFT} -gt 0; then
      echo "> Found valid slot ${slot}, ${BOOT_A_LEFT} attempts remaining"
      setexpr BOOT_A_LEFT ${BOOT_A_LEFT} - 1
      setenv rootfs "${rootfs_A}"
      setenv kdevtype "${kernel_devtype_A}"
      setenv kdevnum "${kernel_devnum_A}"
      setenv kpart "${kernel_part_A}"
    fi
  elif test "${slot}" = "B"; then
    if test ${BOOT_B_LEFT} -gt 0; then
      echo "> Found valid slot ${slot}, ${BOOT_B_LEFT} attempts remaining"
      setexpr BOOT_B_LEFT ${BOOT_B_LEFT} - 1
      setenv rootfs "${rootfs_B}"
      setenv kdevtype "${kernel_devtype_B}"
      setenv kdevnum "${kernel_devnum_B}"
      setenv kpart "${kernel_part_B}"
    fi
  fi
done

if test -n "${rootfs}"; then
  setenv bootargs root=${rootfs} ro rootwait systemd.machine_id=${MACHINE_ID} ${bootargs_extra}
  saveenv
else
  echo "> No valid slot found, resetting tries to 3"
  setenv BOOT_A_LEFT 3
  setenv BOOT_B_LEFT 3
  saveenv
  reset
fi

echo "> Loading Kernel..."
ext4load "${kdevtype}" "${kdevnum}:${kpart}" "${kernel_addr_r}" "boot/${kernel_filename}"

echo "> Loading FDT..."
ext4load "${kdevtype}" "${kdevnum}:${kpart}" "${fdt_addr_r}" "boot/${fdtfile}"

echo "> Booting System..."
bootz "${kernel_addr_r}" - "${fdt_addr_r}"
