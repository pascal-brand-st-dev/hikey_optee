# Makefile for HiKey UEFI boot firmware
#
# 'make help' for details

SHELL = /bin/bash
CURL = curl -L

ifeq ($(V),1)
  Q :=
  ECHO := @:
else
  Q := @
  ECHO := @echo
endif

.PHONY: _all
_all:
	$(Q)$(MAKE) all $(filter-out _all,$(MAKECMDGOALS))

all: build-lloader build-fip build-boot-img build-nvme build-bl30 build-ptable

clean: clean-bl1-bl2-bl31-fip clean-bl33 clean-lloader-ptable
clean: clean-linux-dtb clean-boot-img clean-initramfs clean-optee-linuxdriver
clean: clean-optee-client clean-bl32 clean-aes-perf clean-sha-perf
clean: clean-grub

cleaner: clean cleaner-nvme cleaner-bl30 cleaner-aarch64-gcc cleaner-arm-gcc cleaner-busybox

distclean: cleaner distclean-aarch64-gcc distclean-arm-gcc distclean-busybox distclean-grub

help:
	@echo "Makefile for HiKey board UEFI firmware/kernel"
	@echo
	@echo "- Run 'make' to build the following images:"
	@echo "  LLOADER = $(LLOADER), contains:"
	@echo "      [BL1 = $(BL1)]"
	@echo "      [l-loader/*.S]"
	@echo "  PTABLE = $(PTABLE)"
	@echo "  FIP = $(FIP), contains:"
	@echo "      [BL2 = $(BL2)]"
	@echo "      [BL30 = $(BL30)]"
	@echo "      [BL31 = $(BL31)]"
	@echo "      [BL32 = $(BL32)]"
	@echo "      [BL33 = $(BL33)]"
	@echo "  NVME = $(NVME)"
	@echo "      [downloaded from GitHub]"
	@echo "  BOOT-IMG = $(BOOT-IMG), contains:"
	@echo "      [LINUX = $(LINUX)]"
	@echo "      [DTB = $(DTB)]"
	@echo "      [GRUB = $(GRUB)]"
	@echo "      [INITRAMFS = $(INITRAMFS)], contains:"
	@echo "          [gen_rootfs/busybox/*]"
	@echo "          [OPTEE-LINUXDRIVER = $(optee-linuxdriver-files)]"
	@echo "          [OPTEE-CLIENT = optee_client/out/libteec.so*" \
	                 "optee_client/out/tee-supplicant/tee-supplicant]"
	@echo "          [OPTEE-TEST = optee_test/out/xtest/xtest" \
	                 "optee_test/out/ta/.../*.ta]"
	@echo "- 'make clean' removes most files generated by make, except the"
	@echo "downloaded files/tarballs and the directories they were"
	@echo "extracted to."
	@echo "- 'make cleaner' also removes tar directories."
	@echo "- 'make distclean' removes all generated or downloaded files."
	@echo
	@echo "Image files can be built separately with e.g., 'make build-fip'"
	@echo "or 'make build-bl1', and so on (use the uppercase names above,"
	@echo "make them lowercase and prepend build-)."
	@echo "Note about dependencies: In order to speed up the build and"
	@echo "reduce output when working on a single component, build-<foo>"
	@echo "will NOT invoke build-<bar> automatically."
	@echo "Therefore, if you want to make sure that <bar> is up-to-date,"
	@echo "use 'make build-<foo> build-<bar>'."
	@echo "Plain 'make' or 'make all' do check all dependencies, however."
	@echo
	@echo "Flashing micro-howto:"
	@echo "  # First time flashing the board (or broken eMMC):"
	@echo "  # Set J15 pins 1-2 closed 3-4 closed 5-6 open (recovery mode)"
	@echo "  sudo python burn-boot/hisi-idt.py -d /dev/HiKey --img1=$(LLOADER)"
	@echo "  # Board is now in fastboot mode. Later you may skip the above step"
	@echo "  # and enter fastboot directly by setting:"
	@echo "  # J15 pins 1-2 closed 3-4 open 5-6 closed (fastboot mode)"
	@echo "  fastboot flash ptable $(PTABLE)"
	@echo "  fastboot flash fastboot $(FIP)"
	@echo "  fastboot flash nvme $(NVME)"
	@echo "  fastboot flash boot $(BOOT-IMG)"
	@echo "  # Set J15 pins 1-2 closed 3-4 open 5-6 open (boot from eMMC)"

ifneq (,$(shell which ccache))
CCACHE = ccache # do not remove this comment or the trailing space will go
endif

filename = $(lastword $(subst /, ,$(1)))

# Read stdin, expand ${VAR} environment variables, output to stdout
# http://superuser.com/a/302847
define expand-env-var
awk '{while(match($$0,"[$$]{[^}]*}")) {var=substr($$0,RSTART+2,RLENGTH -3);gsub("[$$]{"var"}",ENVIRON[var])}}1'
endef

BUSYBOX_URL = http://busybox.net/downloads/busybox-1.23.0.tar.bz2
BUSYBOX_TARBALL = $(call filename,$(BUSYBOX_URL))
BUSYBOX_DIR = $(BUSYBOX_TARBALL:.tar.bz2=)

#
# Aarch64 toolchain
#
AARCH64_GCC_URL = https://releases.linaro.org/14.09/components/toolchain/binaries/gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz
AARCH64_GCC_TARBALL = $(call filename,$(AARCH64_GCC_URL))
AARCH64_GCC_DIR = $(AARCH64_GCC_TARBALL:.tar.xz=)
# If you don't want to download the aarch64 toolchain, comment out
# the next line and set CROSS_COMPILE to your compiler command
aarch64-linux-gnu-gcc := toolchains/$(AARCH64_GCC_DIR)
export CROSS_COMPILE ?= $(CCACHE)$(PWD)/toolchains/$(AARCH64_GCC_DIR)/bin/aarch64-linux-gnu-
#export CROSS_COMPILE ?= $(CCACHE)aarch64-linux-gnu-

#
# Aarch32 toolchain
#
ARM_GCC_URL = https://releases.linaro.org/14.09/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux.tar.xz
ARM_GCC_TARBALL = $(call filename,$(ARM_GCC_URL))
ARM_GCC_DIR = $(ARM_GCC_TARBALL:.tar.xz=)
# If you don't want to download the aarch32 toolchain, comment out
# the next line and set CROSS_COMPILE32 to your compiler command
arm-linux-gnueabihf-gcc := toolchains/$(ARM_GCC_DIR)
CROSS_COMPILE32 ?= $(CCACHE)$(PWD)/toolchains/$(ARM_GCC_DIR)/bin/arm-linux-gnueabihf-
#CROSS_COMPILE32 ?= $(CCACHE)arm-linux-gnueabihf-

#
# Download rules
#

downloads/$(AARCH64_GCC_TARBALL):
	$(ECHO) '  CURL    $@'
	$(Q)$(CURL) $(AARCH64_GCC_URL) -o $@

toolchains/$(AARCH64_GCC_DIR): downloads/$(AARCH64_GCC_TARBALL)
	$(ECHO) '  TAR     $@'
	$(Q)rm -rf toolchains/$(AARCH64_GCC_DIR)
	$(Q)cd toolchains && tar xf ../downloads/$(AARCH64_GCC_TARBALL)
	$(Q)touch $@

cleaner-aarch64-gcc:
	$(ECHO) '  CLEANER $@'
	$(Q)rm -rf toolchains/$(AARCH64_GCC_DIR)

distclean-aarch64-gcc:
	$(ECHO) '  DISTCL  $@'
	$(Q)rm -f downloads/$(AARCH64_GCC_TARBALL)

downloads/$(ARM_GCC_TARBALL):
	$(ECHO) '  CURL    $@'
	$(Q)$(CURL) $(ARM_GCC_URL) -o $@

toolchains/$(ARM_GCC_DIR): downloads/$(ARM_GCC_TARBALL)
	$(ECHO) '  TAR     $@'
	$(Q)rm -rf toolchains/$(ARM_GCC_DIR)
	$(Q)cd toolchains && tar xf ../downloads/$(ARM_GCC_TARBALL)
	$(Q)touch $@

cleaner-arm-gcc:
	$(ECHO) '  CLEANER $@'
	$(Q)rm -rf toolchains/$(ARM_GCC_DIR)

distclean-arm-gcc:
	$(ECHO) '  DISTCL  $@'
	$(Q)rm -f downloads/$(ARM_GCC_TARBALL)

.busybox: downloads/$(BUSYBOX_TARBALL)
	$(ECHO) '  TAR     gen_rootfs/busybox'
	$(Q)rm -rf gen_rootfs/$(BUSYBOX_DIR) gen_rootfs/busybox
	$(Q)cd gen_rootfs && tar xf ../downloads/$(BUSYBOX_TARBALL)
	$(Q)mv gen_rootfs/$(BUSYBOX_DIR) gen_rootfs/busybox
	$(Q)touch $@

downloads/$(BUSYBOX_TARBALL):
	$(ECHO) '  CURL    $@'
	$(Q)$(CURL) $(BUSYBOX_URL) -o $@

cleaner-busybox:
	$(ECHO) '  CLEANER $@'
	$(Q)rm -rf gen_rootfs/$(BUSYBOX_DIR) gen_rootfs/busybox .busybox

distclean-busybox:
	$(ECHO) '  DISTCL  $@'
	$(Q)rm -f downloads/$(BUSYBOX_TARBALL)


#
# UEFI
#

EDK2_DEBUG = 0
ifeq ($(EDK2_DEBUG),1)
EDK2_DEB_REL=DEBUG
else
EDK2_DEB_REL=RELEASE
endif

BL33 = edk2/Build/HiKey/$(EDK2_DEB_REL)_GCC49/FV/BL33_AP_UEFI.fd
EDK2_VARS := EDK2_ARCH=AARCH64 EDK2_DSC=HisiPkg/HiKeyPkg/HiKey.dsc EDK2_TOOLCHAIN=GCC49 EDK2_BUILD=$(EDK2_DEB_REL)
# Tell EDK2 to use UART0 for console I/O (defaults to UART3)
EDK2_VARS += EDK2_MACROS="-DSERIAL_BASE=0xF8015000"

.PHONY: build-bl33
build-bl33:: $(aarch64-linux-gnu-gcc)
build-bl33 $(BL33):: .edk2basetools
	$(ECHO) '  BUILD   build-bl33'
	$(Q)set -e ; cd edk2 ; export GCC49_AARCH64_PREFIX='"$(CROSS_COMPILE)"' ; \
	    . edksetup.sh ; \
	    $(MAKE) -j1 -f HisiPkg/HiKeyPkg/Makefile $(EDK2_VARS)
	$(Q)touch ${BL33}

clean-bl33: clean-edk2-basetools
	$(ECHO) '  CLEAN   $@'
	$(Q)set -e ; cd edk2 ; . edksetup.sh ; \
	    $(MAKE) -f HisiPkg/HiKeyPkg/Makefile $(EDK2_VARS) clean

.edk2basetools:
	$(ECHO) '  BUILD   edk2/BaseTools'
	$(Q)set -e ; cd edk2 ; . edksetup.sh ; \
	    $(MAKE) -j1 -C BaseTools CC="$(CCACHE)gcc" CXX="$(CCACHE)g++"
	$(Q)touch $@

clean-edk2-basetools:
	$(ECHO) '  CLEAN   $@'
	$(Q)set -e ; cd edk2 ; . edksetup.sh ; \
	    $(MAKE) -C BaseTools clean
	$(Q)rm -f .edk2basetools

#
# ARM Trusted Firmware
#

ATF_DEBUG = 0
ifeq ($(ATF_DEBUG),1)
ATF = arm-trusted-firmware/build/hikey/debug
else
ATF = arm-trusted-firmware/build/hikey/release
endif
BL1 = $(ATF)/bl1.bin
BL2 = $(ATF)/bl2.bin
BL30 = mcuimage.bin
BL31 = $(ATF)/bl31.bin
# Comment out to not include OP-TEE OS image in fip.bin
BL32 = optee_os/out/arm-plat-hikey/core/tee.bin
FIP = $(ATF)/fip.bin

ARMTF_FLAGS := PLAT=hikey DEBUG=$(ATF_DEBUG)
# TF console now defaults to UART3 (on the low-speed header connector).
# The following line selects UART0 (the unpopulated pads next to J15),
# which is also used by the boot ROM.
ARMTF_FLAGS += CONSOLE_BASE=PL011_UART0_BASE CRASH_CONSOLE_BASE=PL011_UART0_BASE
#ARMTF_FLAGS += LOG_LEVEL=40
ARMTF_EXPORTS := BL30=$(PWD)/$(BL30) BL33=$(PWD)/$(BL33) #CFLAGS=""
ifneq (,$(BL32))
ARMTF_FLAGS += SPD=opteed
ARMTF_EXPORTS += BL32=$(PWD)/$(BL32)
endif

define arm-tf-make
        $(ECHO) '  BUILD   build-$(strip $(1)) [$@]'
        +$(Q)export $(ARMTF_EXPORTS) ; \
	    $(MAKE) -C arm-trusted-firmware $(ARMTF_FLAGS) $(1)
endef

.PHONY: build-bl1
build-bl1 $(BL1): $(aarch64-linux-gnu-gcc)
	$(call arm-tf-make, bl1)

.PHONY: build-bl2
build-bl2 $(BL2): $(aarch64-linux-gnu-gcc)
	$(call arm-tf-make, bl2)

.PHONY: build-bl31
build-bl31 $(BL31): $(aarch64-linux-gnu-gcc)
	$(call arm-tf-make, bl31)


ifneq ($(filter all build-bl2,$(MAKECMDGOALS)),)
tf-deps += build-bl2
endif
ifneq ($(filter all build-bl30,$(MAKECMDGOALS)),)
tf-deps += build-bl30
endif
ifneq ($(filter all build-bl31,$(MAKECMDGOALS)),)
tf-deps += build-bl31
endif
ifneq ($(filter all build-bl32,$(MAKECMDGOALS)),)
tf-deps += build-bl32
endif
ifneq ($(filter all build-bl33,$(MAKECMDGOALS)),)
tf-deps += build-bl33
endif

.PHONY: build-fip
build-fip:: $(tf-deps)
build-fip $(FIP)::
	$(call arm-tf-make, fip)

clean-bl1-bl2-bl31-fip:
	$(ECHO) '  CLEAN   edk2/BaseTools'
	$(Q)export $(ARMTF_EXPORTS) ; \
	    $(MAKE) -C arm-trusted-firmware $(ARMTF_FLAGS) clean

#
# l-loader
#

LLOADER = l-loader/l-loader.bin
PTABLE = l-loader/ptable.img

ifneq ($(filter all build-bl1,$(MAKECMDGOALS)),)
lloader-deps += build-bl1
endif

# FIXME: adding $(BL1) as a dependency [after $(LLOADER)::] breaks
# parallel build (-j) because the same rule is run twice simultaneously
# $ make -j9 build-bl1 build-lloader
#   BUILD   build-bl1 # $@ = build-bl1
#   BUILD   build-bl1 # $@ = arm-trusted-firmware/build/.../bl1.bin
# make[1]: Entering directory '/home/jerome/work/hikey_uefi/arm-trusted-firmware'
# make[1]: Entering directory '/home/jerome/work/hikey_uefi/arm-trusted-firmware'
#   DEPS    build/hikey/debug/bl31/bl31.ld.d
#   DEPS    build/hikey/debug/bl31/bl31.ld.d
.PHONY: build-lloader
build-lloader:: $(lloader-deps)
build-lloader $(LLOADER):: toolchains/$(ARM_GCC_DIR)
	$(ECHO) '  BUILD   build-lloader'
	$(Q)$(MAKE) -C l-loader BL1=$(PWD)/$(BL1) CROSS_COMPILE="$(CROSS_COMPILE32)" l-loader.bin

build-ptable $(PTABLE):
	$(ECHO) '  BUILD   build-ptable'
	$(Q)$(MAKE) -C l-loader ptable.img

clean-lloader-ptable:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C l-loader clean

#
# Linux/DTB
#

# FIXME: 'make build-linux' needlessy (?) recompiles a few files (efi.o...)
# each time it is run

LINUX = linux/arch/arm64/boot/Image
DTB = linux/arch/arm64/boot/dts/hisilicon/hi6220-hikey.dtb
# Config fragments to merge with the default kernel configuration
KCONFIGS += kernel_config/dmabuf.conf
KCONFIGS += kernel_config/usb_net_dm9601.conf
#KCONFIGS += kernel_config/ftrace.conf

.PHONY: build-linux
build-linux:: $(aarch64-linux-gnu-gcc)
build-linux $(LINUX):: linux/.config
	$(ECHO) '  BUILD   build-linux'
	$(Q)flock .linuxbuildinprogress $(MAKE) -C linux ARCH=arm64 LOCALVERSION= Image

build-dtb:: $(aarch64-linux-gnu-gcc)
build-dtb $(DTB):: linux/.config
	$(ECHO) '  BUILD   build-dtb'
	$(Q)flock .linuxbuildinprogress $(MAKE) -C linux ARCH=arm64 LOCALVERSION= dtbs

linux/.config: $(KCONFIGS)
	$(ECHO) '  BUILD   $@'
	$(Q)cd linux && ARCH=arm64 scripts/kconfig/merge_config.sh \
	    arch/arm64/configs/defconfig $(patsubst %,../%,$(KCONFIGS))

linux/usr/gen_init_cpio: linux/.config
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C linux/usr ARCH=arm64 gen_init_cpio

clean-linux-dtb:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C linux ARCH=arm64 clean
	$(Q)rm -f linux/.config
	$(Q)rm -f .linuxbuildinprogress

#
# EFI boot partition
#

BOOT-IMG = boot.img

ifneq ($(filter all build-linux,$(MAKECMDGOALS)),)
boot-img-deps += build-linux
endif
ifneq ($(filter all build-dtb,$(MAKECMDGOALS)),)
boot-img-deps += build-dtb
endif
ifneq ($(filter all build-initramfs,$(MAKECMDGOALS)),)
boot-img-deps += build-initramfs
endif
ifneq ($(filter all build-bl33,$(MAKECMDGOALS)),)
boot-img-deps += build-bl33
endif
ifneq ($(filter all build-grub,$(MAKECMDGOALS)),)
boot-img-deps += build-grub
endif

.PHONY: build-boot-img
build-boot-img:: $(boot-img-deps)
build-boot-img $(BOOT-IMG)::
	$(ECHO) '  GEN    $(BOOT-IMG)'
	$(Q)sudo -p "[sudo] Password:" true
	$(Q)if [ -d .tmpbootimg ] ; then sudo rm -rf .tmpbootimg ; fi
	$(Q)mkdir -p .tmpbootimg
	$(Q)dd if=/dev/zero of=$(BOOT-IMG) bs=512 count=131072 status=none
	$(Q)sudo mkfs.fat -n "BOOT IMG" $(BOOT-IMG) >/dev/null
	$(Q)sudo mount -o loop,rw,sync $(BOOT-IMG) .tmpbootimg
	$(Q)sudo cp $(LINUX) $(DTB) $(GRUB) .tmpbootimg
	$(Q)sudo cp $(INITRAMFS) .tmpbootimg/initrd.img
	$(Q)sudo cp edk2/Build/HiKey/$(EDK2_DEB_REL)_GCC49/AARCH64/AndroidFastbootApp.efi .tmpbootimg/fastboot.efi
	$(Q)sudo umount .tmpbootimg
	$(Q)sudo rm -rf .tmpbootimg

clean-boot-img:
	$(ECHO) '  CLEAN   $@'
	$(Q)rm -f $(BOOT-IMG)

#
# Initramfs
#

INITRAMFS = initramfs.cpio.gz

ifneq ($(filter all build-optee-linuxdriver,$(MAKECMDGOALS)),)
initramfs-deps += build-optee-linuxdriver
endif
ifneq ($(filter all build-optee-client,$(MAKECMDGOALS)),)
initramfs-deps += build-optee-client
endif
ifneq ($(filter all build-aes-perf,$(MAKECMDGOALS)),)
initramfs-deps += build-aes-perf
endif
ifneq ($(filter all build-sha-perf,$(MAKECMDGOALS)),)
initramfs-deps += build-sha-perf
endif
ifneq ($(filter all build-optee-test,$(MAKECMDGOALS)),)
initramfs-deps += build-optee-test
endif

.PHONY: build-initramfs
build-initramfs:: $(initramfs-deps)
build-initramfs $(INITRAMFS):: gen_rootfs/filelist-all.txt linux/usr/gen_init_cpio
	$(ECHO) "  GEN    $(INITRAMFS)"
	$(Q)(cd gen_rootfs && ../linux/usr/gen_init_cpio filelist-all.txt) | gzip >$(INITRAMFS)

gen_rootfs/filelist-all.txt: gen_rootfs/filelist-final.txt initramfs-add-files.txt
	$(ECHO) '  GEN    $@'
	$(Q)cat gen_rootfs/filelist-final.txt | sed '/fbtest/d' >$@
	$(Q)export KERNEL_VERSION=`cd linux ; $(MAKE) --no-print-directory -s kernelversion` ;\
	    export TOP=$(PWD) ; export IFGP=$(IFGP) ; \
	    $(expand-env-var) <initramfs-add-files.txt >>$@

gen_rootfs/filelist-final.txt: .busybox $(aarch64-linux-gnu-gcc)
	$(ECHO) '  GEN    gen_rootfs/filelist-final.txt'
	$(Q)cd gen_rootfs ; \
	    export CC_DIR=$(PWD)/toolchains/$(AARCH64_GCC_DIR) ; \
	    ./generate-cpio-rootfs.sh hikey nocpio

clean-initramfs:
	$(ECHO) "  CLEAN  $@"
	$(Q)cd gen_rootfs ; ./generate-cpio-rootfs.sh hikey clean
	$(Q)rm -f $(INITRAMFS) gen_rootfs/filelist-all.txt gen_rootfs/filelist-final.txt

#
# Grub
#

GRUB = grubaa64.efi grub.cfg

grub-flags := CC="$(CCACHE)gcc" \
	TARGET_CC="$(CROSS_COMPILE)gcc" \
	TARGET_OBJCOPY="$(CROSS_COMPILE)objcopy" \
	TARGET_NM="$(CROSS_COMPILE)nm" \
	TARGET_RANLIB="$(CROSS_COMPILE)ranlib" \
	TARGET_STRIP="$(CROSS_COMPILE)strip"

ifneq ($(filter all build-grub,$(MAKECMDGOALS)),)
.PHONY: grub-force
endif
grub-force:

.PHONY: build-grub
build-grub: $(GRUB)

grubaa64.efi:: grub/grub-mkimage grub-force
	$(ECHO) '  GEN    $@'
	$(Q)cd grub ; grub-mkimage --output=../$@ \
		--config=../grub.configfile \
		--format=arm64-efi \
		--directory=grub-core \
		configfile fat linux normal help part_gpt

grub/grub-mkimage: $(aarch64-linux-gnu-gcc) grub/Makefile grub-force
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C grub

grub/configure: grub/configure.ac
	$(ECHO) '  GEN     $@'
	$(Q)cd grub ; ./autogen.sh

grub/Makefile: grub/configure
	$(ECHO) '  GEN     $@'
	$(Q)cd grub ; ./configure --target=aarch64 --enable-boot-time $(grub-flags)

clean-grub:
	$(ECHO) '  CLEAN       $@'
	$(Q)if [ -e grub/Makefile ] ; then $(MAKE) -C grub clean ; fi
	$(Q)rm -f grubaa64.efi

distclean-grub:
	$(ECHO) '  DISTCLEAN   $@'
	$(Q)if [ -e grub/Makefile ] ; then $(MAKE) -C grub maintainer-clean ; fi

#
# Download nvme.img
#

NVME = nvme.img

.PHONY: build-nvme
build-nvme: $(NVME)

$(NVME):
	$(CURL) https://builds.96boards.org/releases/hikey/linaro/binaries/15.05/nvme.img -o $(NVME)

cleaner-nvme:
	$(ECHO) '  CLEANER $(NVME)'
	$(Q)rm -f $(NVME)

#
# Download mcuimage.bin (packaged as BL30 in FIP)
#

.PHONY: build-bl30
build-bl30: $(BL30)

$(BL30):
	$(CURL) https://builds.96boards.org/releases/hikey/linaro/binaries/15.05/mcuimage.bin -o $(BL30)

cleaner-bl30:
	$(ECHO) '  CLEANER $(BL30)'
	$(Q)rm -f $(BL30)

#
# OP-TEE Linux driver
#

optee-linuxdriver-files := optee_linuxdriver/optee.ko \
                           optee_linuxdriver/optee_armtz.ko

ifneq ($(filter all build-linux,$(MAKECMDGOALS)),)
optee-linuxdriver-deps += build-linux
endif

.PHONY: build-optee-linuxdriver
build-optee-linuxdriver:: $(optee-linuxdriver-deps)
build-optee-linuxdriver $(optee-linuxdriver-files):: $(aarch64-linux-gnu-gcc)
	$(ECHO) '  BUILD   build-optee-linuxdriver'
	$(Q)$(MAKE) -C linux \
	   ARCH=arm64 \
	   LOCALVERSION= \
	   M=../optee_linuxdriver \
	   modules

clean-optee-linuxdriver:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C linux \
	   ARCH=arm64 \
	   LOCALVERSION= \
	   M=../optee_linuxdriver \
	   clean

#
# OP-TEE client library and tee-supplicant executable
#

.PHONY: build-optee-client
build-optee-client: $(aarch64-linux-gnu-gcc)
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C optee_client

clean-optee-client:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C optee_client clean

#
# OP-TEE OS
#

optee-os-flags := CROSS_COMPILE="$(CROSS_COMPILE32)" PLATFORM=hikey
optee-os-flags += DEBUG=0
optee-os-flags += CFG_TEE_CORE_LOG_LEVEL=2 # 0=none 1=err 2=info 3=debug 4=flow
#optee-os-flags += CFG_WITH_PAGER=y
optee-os-flags += CFG_TEE_TA_LOG_LEVEL=3

# 64-bit TEE Core
# FIXME: Compiler bug? xtest 4002 hangs (endless loop) when:
# - TEE Core is 64-bit (OPTEE_64BIT=1 below) and compiler is aarch64-linux-gnu-gcc
#   4.9.2-10ubuntu13, and
# - DEBUG=0, and
# - 32-bit user libraries are built with arm-linux-gnueabihf-gcc 4.9.2-10ubuntu10
# Set DEBUG=1, or set $(arm-linux-gnueabihf-) to build user code with:
#   'arm-linux-gnueabihf-gcc (crosstool-NG linaro-1.13.1-4.8-2013.08 - Linaro GCC 2013.08)
#    4.8.2 20130805 (prerelease)'
# or with:
#   'arm-linux-gnueabihf-gcc (Linaro GCC 2014.11) 4.9.3 20141031 (prerelease)'
# and the problem disappears.
OPTEE_64BIT ?= 0
ifeq ($(OPTEE_64BIT),1)
optee-os-flags += CFG_ARM64_core=y CROSS_COMPILE_core="$(CROSS_COMPILE)"
endif

.PHONY: build-bl32
build-bl32:: $(aarch64-linux-gnu-gcc) $(arm-linux-gnueabihf-gcc)
build-bl32::
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C optee_os $(optee-os-flags)

.PHONY: clean-bl32
clean-bl32:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C optee_os $(optee-os-flags) clean


#
# OP-TEE tests (xtest)
#

# To build with GlobalPlatform tests ("extended xtest"), just extract
# TEE_Initial_Configuration-Test_Suite_v1_1_0_4-2014_11_07.7z under optee_test.
#
# NOTE: If you have built with GlobalPlatform tests and later remove them
# (or force GP_TESTS=0), you will need to clean the repository:
#   cd optee_test ; git reset --hard HEAD
ifneq (,$(wildcard optee_test/TEE_Initial_Configuration-Test_Suite_v1_1_0_4-2014_11_07))
GP_TESTS=1
endif

ifneq ($(GP_TESTS),1)
IFGP=\#
endif

all: build-optee-test
clean: clean-optee-test

optee-test-flags := CROSS_COMPILE_HOST="$(CROSS_COMPILE)" \
		    CROSS_COMPILE_TA="$(CROSS_COMPILE32)" \
		    TA_DEV_KIT_DIR=$(PWD)/optee_os/out/arm-plat-hikey/export-user_ta \
		    O=$(PWD)/optee_test/out #CFG_TEE_TA_LOG_LEVEL=3
ifeq ($(GP_TESTS),1)
optee-test-flags += CFG_GP_TESTSUITE_ENABLE=y \
		    CFG_GP_PACKAGE_PATH=$(PWD)/optee_test/TEE_Initial_Configuration-Test_Suite_v1_1_0_4-2014_11_07 \
		    CFG_DEV_PATH=$(PWD)
optee-test-patch-exports := export CFG_OPTEE_TEST_PATH=$(PWD)/optee_test
endif

ifneq ($(filter all build-bl32,$(MAKECMDGOALS)),)
optee-test-deps += build-bl32
endif
ifneq ($(filter all build-optee-client,$(MAKECMDGOALS)),)
optee-test-deps += build-optee-client
endif
ifeq ($(GP_TESTS),1)
optee-test-deps += optee-test-do-patch
endif


.PHONY: build-optee-test
build-optee-test:: $(optee-test-deps)
build-optee-test:: $(aarch64-linux-gnu-gcc)
	$(ECHO) '  BUILD   $@'
	$(Q)touch optee_test/scripts/.conf
	$(Q)$(MAKE) -C optee_test $(optee-test-flags)

# FIXME:
# No "make clean" in optee_test: fails if optee_os has been cleaned
# previously.
clean-optee-test:
	$(ECHO) '  CLEAN   $@'
	$(Q)rm -rf optee_test/out
	$(Q)rm -f optee_test/scripts/.conf

.PHONY: optee-test-do-patch
optee-test-do-patch:
	$(Q)touch optee_test/scripts/.conf
	$(Q)$(optee-test-patch-exports) ; $(MAKE) -C optee_test $(optee-test-flags) patch


#
# aes-perf (AES crypto performance test)
#

aes-perf-flags := CROSS_COMPILE_HOST="$(CROSS_COMPILE)" \
		  CROSS_COMPILE_TA="$(CROSS_COMPILE32)" \
		  TA_DEV_KIT_DIR=$(PWD)/optee_os/out/arm-plat-hikey/export-user_ta

ifneq ($(filter all build-bl32,$(MAKECMDGOALS)),)
aes-perf-deps += build-bl32
endif
ifneq ($(filter all build-optee-client,$(MAKECMDGOALS)),)
aes-perf-deps += build-optee-client
endif

.PHONY: build-aes-perf
build-aes-perf:: $(aes-perf-deps)
build-aes-perf:: $(aarch64-linux-gnu-gcc)
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C aes-perf $(aes-perf-flags)

clean-aes-perf:
	$(ECHO) '  CLEAN   $@'
	$(Q)rm -rf aes-perf/out

#
# sha-perf (SHA performance test)
#

sha-perf-flags := CROSS_COMPILE_HOST="$(CROSS_COMPILE)" \
		  CROSS_COMPILE_TA="$(CROSS_COMPILE32)" \
		  TA_DEV_KIT_DIR=$(PWD)/optee_os/out/arm-plat-hikey/export-user_ta

ifneq ($(filter all build-bl32,$(MAKECMDGOALS)),)
sha-perf-deps += build-bl32
endif
ifneq ($(filter all build-optee-client,$(MAKECMDGOALS)),)
sha-perf-deps += build-optee-client
endif

.PHONY: build-sha-perf
build-sha-perf:: $(sha-perf-deps)
build-sha-perf:: $(aarch64-linux-gnu-gcc)
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C sha-perf $(sha-perf-flags)

clean-sha-perf:
	$(ECHO) '  CLEAN   $@'
	$(Q)rm -rf sha-perf/out

