MAKEFLAGS := --jobs=$(shell nproc)

RACINE_DIR := $(PWD)/racine
PROJECTS_DIR := $(PWD)/projects
OUTPUT_DIR := $(PWD)/out
BR2_EXTERNAL = $(RACINE_DIR):$(PROJECTS_DIR)

CCACHE_CONFIG_FRAGMENT = $(PWD)/support/config-fragments/ccache.config

export BR2_DL_DIR = $(OUTPUT_DIR)/dl
export BR2_CCACHE_DIR = $(OUTPUT_DIR)/ccache

.PHONY: all
all: raspberrypi

buildroot/.git:
	git submodule update --init

define define_board
.PHONY: $(1)_defconfig
$(1)_defconfig: buildroot/.git
	mkdir -p $$(OUTPUT_DIR)/$(1)/

	# merge config fragments. Call make ourselves (-m) to have proper make recursion
	cd buildroot ; \
		./support/kconfig/merge_config.sh \
			-m \
			-e $$(BR2_EXTERNAL) \
			-O $$(OUTPUT_DIR)/$(1)/ \
			$$(PROJECTS_DIR)/configs/$(1)_defconfig \
			$$(CCACHE_CONFIG_FRAGMENT) ; \
		$$(MAKE) \
			KCONFIG_ALLCONFIG=$$(OUTPUT_DIR)/$(1)/.config \
			BR2_EXTERNAL=$$(BR2_EXTERNAL) \
			O=$$(OUTPUT_DIR)/$(1)/ \
			alldefconfig

.PHONY: $(1)
$(1): $(1)_defconfig
	$$(MAKE) -C $$(OUTPUT_DIR)/$(1)/

endef

$(eval $(call define_board,raspberrypi))

.PHONY: clean
clean:
	$(MAKE) -C $(OUTPUT_DIR)/raspberrypi/ clean
