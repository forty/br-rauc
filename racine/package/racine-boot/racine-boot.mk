RACINE_BOOT_SITE = $(BR2_EXTERNAL_RACINE_PATH)/package/racine-boot/files
RACINE_BOOT_SITE_METHOD = local
RACINE_BOOT_DEPENDENCIES = linux uboot host-uboot-tools host-openssl
RACINE_BOOT_INSTALL_IMAGES = YES

# TODO
# - Fail if BR2_PACKAGE_HOST_UBOOT_TOOLS_BOOT_SCRIPT is y
# - Fail if BR2_PACKAGE_HOST_UBOOT_TOOLS_ENVIMAGE is y

define RACINE_BOOT_LINUX_CONFIG_FIXUPS
	# Requirement for RAUC
	$(call KCONFIG_ENABLE_OPT,CONFIG_MD)
	$(call KCONFIG_ENABLE_OPT,CONFIG_BLK_DEV_DM)
	$(call KCONFIG_ENABLE_OPT,CONFIG_BLK_DEV_LOOP)
	$(call KCONFIG_ENABLE_OPT,CONFIG_DM_VERITY)
	$(call KCONFIG_ENABLE_OPT,CONFIG_SQUASHFS)
	$(call KCONFIG_ENABLE_OPT,CONFIG_CRYPTO_SHA256)
endef

RACINE_BOOT_RAUC_CONF_FILE = $(@D)/rauc.conf
RACINE_BOOT_FW_ENV_FILE = $(@D)/fw_env.config
RACINE_BOOT_UBOOT_ENV_FILE = $(@D)/uboot.env
RACINE_BOOT_UBOOT_ENV_BIN_FILE = $(@D)/uboot-env.bin
RACINE_BOOT_UBOOT_SCRIPT_FILE = $(@D)/uboot.scr

RACINE_BOOT_RAUC_COMPATIBLE = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_RAUC_COMPATIBLE))
RACINE_BOOT_ROOTFS_A = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_ROOTFS_A))
RACINE_BOOT_ROOTFS_B = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_ROOTFS_B))
RACINE_BOOT_BOOTARGS = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_BOOTARGS))
RACINE_BOOT_UBOOT_DEVICE_TYPE = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_UBOOT_DEVICE_TYPE))
RACINE_BOOT_UBOOT_DEVICE_NUMBER = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_UBOOT_DEVICE_NUMBER))

define racine-boot-setenv # variable-name, variable-value
	echo $1=$2 >> $(RACINE_BOOT_UBOOT_ENV_FILE)
endef

define RACINE_BOOT_BUILD_UBOOT_ENV_CMD
	CROSS_COMPILE="$(TARGET_CROSS)" \
		$(UBOOT_SRCDIR)/scripts/get_default_envs.sh \
		$(UBOOT_SRCDIR) \
		> $(RACINE_BOOT_UBOOT_ENV_FILE)

	$(call racine-boot-setenv,kernel_filename,$(LINUX_IMAGE_NAME))
	$(call racine-boot-setenv,fdtfile,bcm2708-rpi-b.dtb) # TODO make it configurable or clever
	$(call racine-boot-setenv,bootargs_extra,'$(RACINE_BOOT_BOOTARGS)')
	$(call racine-boot-setenv,devtype,$(RACINE_BOOT_UBOOT_DEVICE_TYPE))
	$(call racine-boot-setenv,devnum,$(RACINE_BOOT_UBOOT_DEVICE_NUMBER))
	$(call racine-boot-setenv,boot_part,1)
	$(call racine-boot-setenv,kernel_part_A,2)
	$(call racine-boot-setenv,kernel_part_B,3)
	$(call racine-boot-setenv,rootfs_A,$(RACINE_BOOT_ROOTFS_A))
	$(call racine-boot-setenv,rootfs_B,$(RACINE_BOOT_ROOTFS_B))
	$(call racine-boot-setenv,bootcmd,'fatload $${devtype} $${devnum}:$${boot_part} $${scriptaddr} boot.scr; source $${scriptaddr}')

	cat $(RACINE_BOOT_UBOOT_ENV_FILE) | \
		$(HOST_DIR)/bin/mkenvimage -s $(BR2_PACKAGE_RACINE_BOOT_UBOOT_ENV_SIZE) \
		$(if $(filter "BIG",$(BR2_ENDIAN)),-b) \
		-o $(RACINE_BOOT_UBOOT_ENV_BIN_FILE) \
		-
endef

define RACINE_BOOT_BUILD_UBOOT_SCRIPT_CMD
	$(HOST_DIR)/bin/mkimage -C none -A $(MKIMAGE_ARCH) -T script \
		-d $(@D)/uboot.cmd \
		$(RACINE_BOOT_UBOOT_SCRIPT_FILE)
endef

define RACINE_BOOT_BUILD_FW_ENV_FILE_CMD
	echo \
		$(BR2_PACKAGE_RACINE_BOOT_UBOOT_ENV_DEVICE) \
		$(BR2_PACKAGE_RACINE_BOOT_UBOOT_ENV_OFFSET) \
		$(BR2_PACKAGE_RACINE_BOOT_UBOOT_ENV_SIZE) \
		> $(RACINE_BOOT_FW_ENV_FILE)
endef

define RACINE_BOOT_BUILD_RAUC_CONF_FILE_CMD
	sed \
		-e 's|@RACINE_BOOT_RAUC_COMPATIBLE@|$(RACINE_BOOT_RAUC_COMPATIBLE)|g' \
		-e 's|@RACINE_BOOT_ROOTFS_A@|$(RACINE_BOOT_ROOTFS_A)|g' \
		-e 's|@RACINE_BOOT_ROOTFS_B@|$(RACINE_BOOT_ROOTFS_B)|g' \
		$(@D)/rauc.conf.in > $(RACINE_BOOT_RAUC_CONF_FILE)
endef

define RACINE_BOOT_BUILD_CMDS
	$(RACINE_BOOT_BUILD_UBOOT_ENV_CMD)
	$(RACINE_BOOT_BUILD_UBOOT_SCRIPT_CMD)
	$(RACINE_BOOT_BUILD_FW_ENV_FILE_CMD)
	$(RACINE_BOOT_BUILD_RAUC_CONF_FILE_CMD)
endef

define RACINE_BOOT_INSTALL_RAUC_CERTIFICATE_CMD
	# TODO take key & certificate as env variables
	echo "/!\\ Generating temporary key for the build /!\\"
	$(HOST_DIR)/bin/openssl req \
		-x509 \
		-newkey rsa:4096 \
		-nodes \
		-keyout $(BINARIES_DIR)/key.pem \
		-out $(BINARIES_DIR)/cert.pem \
		-subj "/O=br-rauc/CN=temp-build-cert"
	ln -sf $(BINARIES_DIR)/cert.pem $(BINARIES_DIR)/ca.pem

	mkdir -p $(TARGET_DIR)/etc/rauc/
	cp -L $(BINARIES_DIR)/ca.pem $(TARGET_DIR)/etc/rauc/ca.pem
endef

define RACINE_BOOT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m0644 $(RACINE_BOOT_FW_ENV_FILE) \
	 	$(TARGET_DIR)/etc/fw_env.config

	# Required by fw_printenv
	mkdir -p $(TARGET_DIR)/var/lock

	mkdir -p $(TARGET_DIR)/etc/rauc/
	$(INSTALL) -D -m0644 $(RACINE_BOOT_RAUC_CONF_FILE) \
		$(TARGET_DIR)/etc/rauc/system.conf

	$(INSTALL) -D -m0644 \
		$(@D)/rauc-mark-good.service \
		$(TARGET_DIR)/usr/lib/systemd/system/rauc-mark-good.service

	$(RACINE_BOOT_INSTALL_RAUC_CERTIFICATE_CMD)
endef

define RACINE_BOOT_INSTALL_IMAGES_CMDS
	$(INSTALL) -m 0644 -D $(RACINE_BOOT_UBOOT_ENV_BIN_FILE) $(BINARIES_DIR)/uboot-env.bin
	$(INSTALL) -m 0644 -D $(RACINE_BOOT_UBOOT_SCRIPT_FILE) $(BINARIES_DIR)/boot.scr
endef

$(eval $(generic-package))