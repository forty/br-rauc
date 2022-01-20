RACINE_DATA_SITE = $(BR2_EXTERNAL_RACINE_PATH)/package/racine-data/files
RACINE_DATA_SITE_METHOD = local
RACINE_DATA_DEPENDENCIES = host-e2tools host-e2fsprogs
RACINE_DATA_INSTALL_IMAGES = YES

RACINE_DATA_DATA_EXT4_FILE = $(@D)/data.ext4
RACINE_DATA_DIRS_TO_CREATE = /etc /.etc_work /var /.var_work /home /.home_work

define RACINE_DATA_BUILD_DATA_EXT4_CMD
	rm -f $(RACINE_DATA_DATA_EXT4_FILE)
	$(HOST_DIR)/sbin/mkfs.ext4 -r 1 -N 0 -m 5 -L "data" -O ^64bit $(RACINE_DATA_DATA_EXT4_FILE) "32M"

	for dir in $(RACINE_DATA_DIRS_TO_CREATE); do \
		$(HOST_DIR)/bin/e2mkdir -G 0 -O 0 - P 700 $(RACINE_DATA_DATA_EXT4_FILE):$${dir}; \
	done
endef

define RACINE_DATA_BUILD_CMDS
	$(RACINE_DATA_BUILD_DATA_EXT4_CMD)
endef

define RACINE_DATA_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/data

	$(INSTALL) -D -m 0755 $(@D)/expand-data-part $(TARGET_DIR)/usr/sbin/expand-data-part
	$(INSTALL) -D -m 0644 $(@D)/fstab $(TARGET_DIR)/etc/fstab
endef

define RACINE_DATA_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/expand-data-part.service \
		$(TARGET_DIR)/usr/lib/systemd/system/expand-data-part.service
endef

define RACINE_DATA_INSTALL_IMAGES_CMDS
	$(INSTALL) -m 0644 -D $(RACINE_DATA_DATA_EXT4_FILE) $(BINARIES_DIR)/data.ext4
endef

$(eval $(generic-package))
