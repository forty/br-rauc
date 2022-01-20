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
RACINE_BOOT_UBOOT_ENV_FILE = $(@D)/uboot.env
RACINE_BOOT_UBOOT_ENV_BIN_FILE = $(@D)/uboot-env.bin
RACINE_BOOT_UBOOT_SCRIPT_FILE = $(@D)/uboot.scr
RACINE_BOOT_GENIMAGE_CONF_FILE = $(@D)/genimage.cfg

RACINE_BOOT_ROOTFS_A_UUID = 7c49f947-5fc3-4377-8db7-749e65844748
RACINE_BOOT_ROOTFS_B_UUID = 3324f67b-2ce6-45c2-a620-97d81ea02278
RACINE_BOOT_ROOTFS_A_LABEL = rootfsa
RACINE_BOOT_ROOTFS_B_LABEL = rootfsb

RACINE_BOOT_RAUC_COMPATIBLE = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_RAUC_COMPATIBLE))
RACINE_BOOT_RAUC_VERSION = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_RAUC_VERSION))
RACINE_BOOT_BOOTARGS = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_BOOTARGS))
RACINE_BOOT_GENIMAGE_TEMPLATE = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_GENIMAGE_TEMPLATE))
RACINE_BOOT_UBOOT_ENV_CONFIG_FILE = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_UBOOT_ENV_CONFIG_FILE))
RACINE_BOOT_UBOOT_ENV_SIZE = $(call qstrip,$(BR2_PACKAGE_RACINE_BOOT_UBOOT_ENV_SIZE))

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
	$(call racine-boot-setenv,rootfs_A_uuid,$(RACINE_BOOT_ROOTFS_A_UUID))
	$(call racine-boot-setenv,rootfs_B_uuid,$(RACINE_BOOT_ROOTFS_B_UUID))

	cat $(RACINE_BOOT_UBOOT_ENV_FILE) | \
		$(HOST_DIR)/bin/mkenvimage -s $(RACINE_BOOT_UBOOT_ENV_SIZE) \
		$(if $(filter "BIG",$(BR2_ENDIAN)),-b) \
		-o $(RACINE_BOOT_UBOOT_ENV_BIN_FILE) \
		-
endef

define RACINE_BOOT_BUILD_UBOOT_SCRIPT_CMD
	$(HOST_DIR)/bin/mkimage -C none -A $(MKIMAGE_ARCH) -T script \
		-d $(@D)/uboot.cmd \
		$(RACINE_BOOT_UBOOT_SCRIPT_FILE)
endef

define RACINE_BOOT_BUILD_RAUC_CONF_FILE_CMD
	sed \
		-e 's|@RACINE_BOOT_RAUC_COMPATIBLE@|$(RACINE_BOOT_RAUC_COMPATIBLE)|g' \
		-e 's|@RACINE_BOOT_ROOTFS_A_UUID@|$(RACINE_BOOT_ROOTFS_A_UUID)|g' \
		-e 's|@RACINE_BOOT_ROOTFS_B_UUID@|$(RACINE_BOOT_ROOTFS_B_UUID)|g' \
		$(@D)/rauc.conf.in > $(RACINE_BOOT_RAUC_CONF_FILE)
endef

define RACINE_BOOT_BUILD_GENIMAGE_CONF_FILE_CMD
	sed \
		-e 's|@RACINE_BOOT_RAUC_COMPATIBLE@|$(RACINE_BOOT_RAUC_COMPATIBLE)|g' \
		-e 's|@RACINE_BOOT_RAUC_VERSION@|$(RACINE_BOOT_RAUC_VERSION)|g' \
		-e 's|@RACINE_BOOT_ROOTFS_A_UUID@|$(RACINE_BOOT_ROOTFS_A_UUID)|g' \
		-e 's|@RACINE_BOOT_ROOTFS_B_UUID@|$(RACINE_BOOT_ROOTFS_B_UUID)|g' \
		-e 's|@RACINE_BOOT_ROOTFS_A_LABEL@|$(RACINE_BOOT_ROOTFS_A_LABEL)|g' \
		-e 's|@RACINE_BOOT_ROOTFS_B_LABEL@|$(RACINE_BOOT_ROOTFS_B_LABEL)|g' \
	 	$(RACINE_BOOT_GENIMAGE_TEMPLATE) > $(RACINE_BOOT_GENIMAGE_CONF_FILE)
endef

define RACINE_BOOT_BUILD_CMDS
	$(RACINE_BOOT_BUILD_UBOOT_ENV_CMD)
	$(RACINE_BOOT_BUILD_UBOOT_SCRIPT_CMD)
	$(RACINE_BOOT_BUILD_RAUC_CONF_FILE_CMD)
	$(RACINE_BOOT_BUILD_GENIMAGE_CONF_FILE_CMD)
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
		-subj "/O=racine/CN=temp-build-cert"
	ln -sf $(BINARIES_DIR)/cert.pem $(BINARIES_DIR)/ca.pem

	mkdir -p $(TARGET_DIR)/etc/rauc/
	cp -L $(BINARIES_DIR)/ca.pem $(TARGET_DIR)/etc/rauc/ca.pem
endef

define RACINE_BOOT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m0644 $(RACINE_BOOT_UBOOT_ENV_CONFIG_FILE) \
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
	$(INSTALL) -m 0644 -D $(RACINE_BOOT_GENIMAGE_CONF_FILE) $(BINARIES_DIR)/genimage.cfg
endef

$(eval $(generic-package))
