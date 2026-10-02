# Cross toolchain for flash.tos, pinned to what reproduces the original images:
#   binutils 2.9.1-mint (TOS part assembler, linker and objcopy for everything),
#   gcc 3.3.2-mint (TOS part), gcc 4.4.2-mint with binutils 2.19.1-mint as assembler (drivers),
#   MiNTLib headers as the drivers were built with (0.57.3 + newer bindings/sysvars).
# Result in $(PREFIX); bin/tos-gcc and bin/drivers-gcc use it.

PREFIX   = $(CURDIR)/install
BUILD    = $(CURDIR)/build
DOWNLOAD = $(CURDIR)/download
JOBS     = $(shell nproc)
DOCKER   = docker

# m68k-atari-mint-binutils-gdb: binutils 2.9.1 with Frank Naumann's MiNT patches (binutils-2_9-mint branch),
# binutils-2.19.1-mint-20091017 (binutils-2_19-mint branch)
BINUTILS291 = 72dcc78997af2e015858bfcb1be962d05935fcfe
BINUTILS219 = fcc65f2d43409f65ac34b4e5a3e4b55598fa2ac2
GMP      = gmp-6.3.0
MPFR     = mpfr-3.1.4
GCC44    = c5cda7f05e317affcada17895205e47b53db031a
GCC33    = aae3693cb321434efb9acb34617f066288d16e56
# MiNTLib 0.57.3; mint/osbind.h, mint/mintbind.h, compiler.h of 2009-05-22; mint/sysvars.h of 2010-04-13
MINTLIB  = fca0b5ff640add78af0c9886a23e8a17751c9f62
MINTLIB_BIND = cccae1c06a7218edaa69cdd6bad4ecd79c23df70
MINTLIB_SYSVARS = e88e6afc61b0f762e601c253b81c9fa692b6f4b9

# m68k-atari-mint-gcc: gcc-4.4.2-mint-20091017 (gcc-4_4-mint branch), gcc-3_3-mint-vri branch
URLS = \
	https://github.com/freemint/m68k-atari-mint-binutils-gdb/archive/$(BINUTILS291).tar.gz \
	https://github.com/freemint/m68k-atari-mint-binutils-gdb/archive/$(BINUTILS219).tar.gz \
	https://ftp.gnu.org/gnu/gmp/$(GMP).tar.xz \
	https://ftp.gnu.org/gnu/mpfr/$(MPFR).tar.xz \
	https://github.com/freemint/m68k-atari-mint-gcc/archive/$(GCC44).tar.gz \
	https://github.com/freemint/m68k-atari-mint-gcc/archive/$(GCC33).tar.gz \
	https://github.com/freemint/mintlib/archive/$(MINTLIB).tar.gz \
	https://github.com/freemint/mintlib/archive/$(MINTLIB_BIND).tar.gz \
	https://github.com/freemint/mintlib/archive/$(MINTLIB_SYSVARS).tar.gz

GCC_OLD_HOST = -std=gnu89 -fgnu89-inline -fcommon -w

all: $(PREFIX)/.binutils291 $(PREFIX)/.binutils219 $(PREFIX)/.sysroot $(PREFIX)/.gcc44 $(PREFIX)/.gcc33

$(DOWNLOAD)/.ok: SHA256SUMS
	mkdir -p $(DOWNLOAD)
	cd $(DOWNLOAD) && for u in $(URLS); do \
		f=$$(basename $$u); \
		case $$u in */archive/*) f=$$(echo $$u | cut -d/ -f5)-$$f;; esac; \
		[ -f $$f ] || { curl -fL -o $$f.part $$u && mv $$f.part $$f; } || exit 1; \
	done
	cd $(DOWNLOAD) && sha256sum -c $(CURDIR)/SHA256SUMS
	touch $@

# binutils: 32-bit host programs built in the i386 container, like the compilers
$(PREFIX)/.binutils291: $(DOWNLOAD)/.ok patches/binutils-2.9.1-mint-host.patch docker/Dockerfile
	rm -rf $(BUILD)/m68k-atari-mint-binutils-gdb-$(BINUTILS291) $(BUILD)/binutils291 $(PREFIX)/binutils-2.9.1
	mkdir -p $(BUILD)/binutils291
	tar xzf $(DOWNLOAD)/m68k-atari-mint-binutils-gdb-$(BINUTILS291).tar.gz -C $(BUILD)
	patch -d $(BUILD)/m68k-atari-mint-binutils-gdb-$(BINUTILS291) -p1 < patches/binutils-2.9.1-mint-host.patch
	$(DOCKER) build -t flash-tos-gcc33-host docker
	mkdir -p $(PREFIX)
	$(DOCKER) run --rm -u $$(id -u):$$(id -g) -v $(BUILD):$(BUILD) -v $(PREFIX):$(PREFIX) -w $(BUILD)/binutils291 \
		flash-tos-gcc33-host sh -c 'set -e; \
		CC="gcc $(GCC_OLD_HOST)" $(BUILD)/m68k-atari-mint-binutils-gdb-$(BINUTILS291)/configure \
			--target=m68k-atari-mint --prefix=$(PREFIX)/binutils-2.9.1 \
			--build=i686-pc-linux-gnu --host=i686-pc-linux-gnu --disable-nls && \
		make -j$(JOBS) MAKEINFO=true LDFLAGS=-all-static all-gas all-ld all-binutils && \
		make MAKEINFO=true install-gas install-ld install-binutils'
	touch $@

# assembler only
$(PREFIX)/.binutils219: $(DOWNLOAD)/.ok patches/binutils-2.19.1-mint-host.patch docker/Dockerfile
	rm -rf $(BUILD)/m68k-atari-mint-binutils-gdb-$(BINUTILS219) $(BUILD)/binutils219 $(PREFIX)/binutils-2.19.1
	mkdir -p $(BUILD)/binutils219
	tar xzf $(DOWNLOAD)/m68k-atari-mint-binutils-gdb-$(BINUTILS219).tar.gz -C $(BUILD)
	patch -d $(BUILD)/m68k-atari-mint-binutils-gdb-$(BINUTILS219) -p1 < patches/binutils-2.19.1-mint-host.patch
	$(DOCKER) build -t flash-tos-gcc33-host docker
	mkdir -p $(PREFIX)
	$(DOCKER) run --rm -u $$(id -u):$$(id -g) -v $(BUILD):$(BUILD) -v $(PREFIX):$(PREFIX) -w $(BUILD)/binutils219 \
		flash-tos-gcc33-host sh -c 'set -e; \
		CC="gcc $(GCC_OLD_HOST)" $(BUILD)/m68k-atari-mint-binutils-gdb-$(BINUTILS219)/configure \
			--target=m68k-atari-mint --prefix=$(PREFIX)/binutils-2.19.1 \
			--build=i686-pc-linux-gnu --host=i686-pc-linux-gnu --disable-nls --disable-werror && \
		make -j$(JOBS) MAKEINFO=true all-gas && \
		rm gas/as-new && make -C gas MAKEINFO=true LDFLAGS=-all-static as-new && \
		make MAKEINFO=true install-gas'
	touch $@

# headers only
$(PREFIX)/.sysroot: $(DOWNLOAD)/.ok patches/mintlib-2012-compat.patch
	rm -rf $(BUILD)/mintlib-$(MINTLIB) $(BUILD)/mintlib-$(MINTLIB_BIND) $(BUILD)/mintlib-$(MINTLIB_SYSVARS) \
		$(PREFIX)/sys-root
	mkdir -p $(BUILD) $(PREFIX)/sys-root/usr
	for m in $(MINTLIB) $(MINTLIB_BIND) $(MINTLIB_SYSVARS); do \
		tar xzf $(DOWNLOAD)/mintlib-$$m.tar.gz -C $(BUILD) || exit 1; \
	done
	cp -r $(BUILD)/mintlib-$(MINTLIB)/include $(PREFIX)/sys-root/usr/include
	cd $(BUILD)/mintlib-$(MINTLIB_BIND)/include && \
		cp compiler.h mint/osbind.h mint/mintbind.h --parents $(PREFIX)/sys-root/usr/include/
	cp $(BUILD)/mintlib-$(MINTLIB_SYSVARS)/include/mint/sysvars.h $(PREFIX)/sys-root/usr/include/mint/
	cd $(PREFIX)/sys-root/usr/include && \
		sed -e 's/@MAJOR@/0/' -e 's/@MINOR@/57/' -e 's/@REVISION@/3/' -e 's/@BETATAG@/""/' \
			features.h.in > features.h && \
		sed -e 's/@LINKER_TYPE@/GNU/' linker.h.in > linker.h
	patch -d $(PREFIX)/sys-root/usr/include -p1 < patches/mintlib-2012-compat.patch
	touch $@

# driver + cc1 only, built as 32-bit host programs in the i386 container: on a 64-bit host
# (64-bit HOST_WIDE_INT) gcc 4.4 folds some constants and allocates some registers differently
$(PREFIX)/.gcc44: $(DOWNLOAD)/.ok $(PREFIX)/.sysroot docker/Dockerfile
	rm -rf $(BUILD)/m68k-atari-mint-gcc-$(GCC44) $(BUILD)/gcc44 $(BUILD)/$(GMP) $(BUILD)/$(MPFR) \
		$(BUILD)/gmp32 $(BUILD)/mpfr32 $(BUILD)/hostlibs $(PREFIX)/gcc-4.4.2
	mkdir -p $(BUILD)/gcc44 $(BUILD)/gmp32 $(BUILD)/mpfr32
	tar xzf $(DOWNLOAD)/m68k-atari-mint-gcc-$(GCC44).tar.gz -C $(BUILD)
	tar xf $(DOWNLOAD)/$(GMP).tar.xz -C $(BUILD)
	tar xf $(DOWNLOAD)/$(MPFR).tar.xz -C $(BUILD)
	$(DOCKER) build -t flash-tos-gcc33-host docker
	mkdir -p $(PREFIX)
	$(DOCKER) run --rm -u $$(id -u):$$(id -g) -v $(BUILD):$(BUILD) -v $(PREFIX):$(PREFIX) -w $(BUILD) \
		flash-tos-gcc33-host sh -c 'set -e; \
		cd $(BUILD)/gmp32 && $(BUILD)/$(GMP)/configure --build=i686-pc-linux-gnu ABI=32 \
			--prefix=$(BUILD)/hostlibs --disable-shared --enable-static && \
		make -j$(JOBS) install && \
		cd $(BUILD)/mpfr32 && $(BUILD)/$(MPFR)/configure --build=i686-pc-linux-gnu \
			--prefix=$(BUILD)/hostlibs --with-gmp=$(BUILD)/hostlibs --disable-shared --enable-static && \
		make -j$(JOBS) install && \
		cd $(BUILD)/gcc44 && CC="gcc $(GCC_OLD_HOST)" $(BUILD)/m68k-atari-mint-gcc-$(GCC44)/configure \
			--target=m68k-atari-mint --build=i686-pc-linux-gnu --host=i686-pc-linux-gnu \
			--prefix=$(PREFIX)/gcc-4.4.2 --with-gmp=$(BUILD)/hostlibs --with-mpfr=$(BUILD)/hostlibs \
			--with-gnu-as --with-gnu-ld --enable-languages=c --disable-nls --disable-multilib \
			--disable-libssp --disable-shared --disable-bootstrap --disable-threads --without-headers \
			--with-native-system-header-dir=/usr/include --with-sysroot=$(PREFIX)/sys-root \
			MAKEINFO=true && \
		make -j$(JOBS) MAKEINFO=true LDFLAGS=-static all-gcc && \
		make MAKEINFO=true install-gcc'
	touch $@

# driver + cc1 only (no libgcc), built as static 32-bit host programs in an i386 container
$(PREFIX)/.gcc33: $(DOWNLOAD)/.ok patches/gcc-3.3.2-mint-host.patch docker/Dockerfile
	rm -rf $(BUILD)/m68k-atari-mint-gcc-$(GCC33) $(BUILD)/gcc33 $(PREFIX)/gcc-3.3.2
	mkdir -p $(BUILD)/gcc33
	tar xzf $(DOWNLOAD)/m68k-atari-mint-gcc-$(GCC33).tar.gz -C $(BUILD)
	patch -d $(BUILD)/m68k-atari-mint-gcc-$(GCC33) -p1 < patches/gcc-3.3.2-mint-host.patch
	$(DOCKER) build -t flash-tos-gcc33-host docker
	mkdir -p $(PREFIX)
	$(DOCKER) run --rm -u $$(id -u):$$(id -g) -v $(BUILD):$(BUILD) -v $(PREFIX):$(PREFIX) -w $(BUILD)/gcc33 \
		flash-tos-gcc33-host sh -c '\
		CC="gcc $(GCC_OLD_HOST) -O1" $(BUILD)/m68k-atari-mint-gcc-$(GCC33)/configure \
			--target=m68k-atari-mint --prefix=$(PREFIX)/gcc-3.3.2 \
			--build=i686-pc-linux-gnu --host=i686-pc-linux-gnu --with-gnu-as --with-gnu-ld \
			--enable-languages=c --disable-nls --disable-multilib --disable-shared --disable-threads && \
		make MAKEINFO=true all-libiberty && \
		make -C gcc MAKEINFO=true LDFLAGS=-static xgcc cc1 specs stmp-int-hdrs'
	mkdir -p $(PREFIX)/gcc-3.3.2/bin $(PREFIX)/gcc-3.3.2/lib/gcc-lib/m68k-atari-mint/3.3.2
	cp $(BUILD)/gcc33/gcc/xgcc $(PREFIX)/gcc-3.3.2/bin/m68k-atari-mint-gcc
	cp -r $(BUILD)/gcc33/gcc/cc1 $(BUILD)/gcc33/gcc/specs $(BUILD)/gcc33/gcc/include \
		$(PREFIX)/gcc-3.3.2/lib/gcc-lib/m68k-atari-mint/3.3.2/
	touch $@

clean:
	rm -rf $(BUILD)

distclean: clean
	rm -rf $(PREFIX) $(DOWNLOAD)

.PHONY: all clean distclean
