RACINE_DATA_SITE = $(BR2_EXTERNAL_RACINE_PATH)/package/racine-data/files
RACINE_DATA_SITE_METHOD = local

define RACINE_DATA_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/data

	$(INSTALL) -D -m 0755 $(@D)/mount-data-part $(TARGET_DIR)/usr/sbin/mount-data-part
	$(INSTALL) -D -m 0644 $(@D)/persist.list $(TARGET_DIR)/etc/persist.list

	for fs in $$(cat $(@D)/persist.list); do \
		if [ ! -e "$(TARGET_DIR)$${fs}" ]; then \
			last=$$(echo -n "$${fs}" | tail -c 1) ; \
			if [ "$${last}" = / ]; then \
				mkdir -p "$(TARGET_DIR)$${fs}"; \
			else \
				touch "$(TARGET_DIR)$${fs}"; \
			fi \
		fi \
	done
endef

define RACINE_DATA_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/mount-data-part.service \
		$(TARGET_DIR)/usr/lib/systemd/system/mount-data-part.service
endef

$(eval $(generic-package))
