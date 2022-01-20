MAKEFLAGS := --jobs=$(shell nproc)

RACINE_DIR := $(PWD)/racine
OUTPUT_DIR := $(PWD)/out

export BR2_DL_DIR = $(OUTPUT_DIR)/dl
export BR2_CCACHE_DIR = $(OUTPUT_DIR)/ccache

.PHONY: all
all: raspberrypi

buildroot/.git:
	git submodule update --init

.PHONY: raspberrypi_defconfig
raspberrypi_defconfig: buildroot/.git
	mkdir -p $(OUTPUT_DIR)/raspberrypi/
	cd buildroot ; \
		./support/kconfig/merge_config.sh \
			-e $(RACINE_DIR)\
			-O $(OUTPUT_DIR)/raspberrypi/ \
			$(RACINE_DIR)/configs/raspberrypi_defconfig \
			$(PWD)/support/config-fragments/ccache.config

.PHONY: raspberrypi
raspberrypi: raspberrypi_defconfig
	$(MAKE) -C $(OUTPUT_DIR)/raspberrypi/

.PHONY: clean
clean:
	$(MAKE) -C $(OUTPUT_DIR)/raspberrypi/ clean
