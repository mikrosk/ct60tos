# Cross toolchain for flash.tos, pinned to what reproduces the original images:
#   binutils 2.45 (m68k-elf) with old gas behaviour on request (GAS_M68K_OLD),
#   gcc 3.3.2-mint (TOS part C files), gcc 4.4.3-mint (drivers),
#   MiNTLib/fdlibm headers adjusted to the 2012 MiNTLib the drivers were built with.
# Result in $(PREFIX); bin/tos-gcc, bin/drivers-gcc and bin/m68k-as use it.

PREFIX   = $(CURDIR)/install
BUILD    = $(CURDIR)/build
DOWNLOAD = $(CURDIR)/download
JOBS     = $(shell nproc)
DOCKER   = docker
HOSTCC   = gcc

BINUTILS = binutils-2.45
GMP      = gmp-6.3.0
MPFR     = mpfr-3.1.4
GCC44    = 53af72da5373d93816177a7d2e6a45e088c98c52
GCC33    = aae3693cb321434efb9acb34617f066288d16e56
MINTLIB  = 58620c01ed044ec13a40515d5bac6388f2fd914e
FDLIBM   = 61c059fed98e2ed8d26ca39617321134b33e535a

# gcc-4_4-mint and gcc-3_3-mint-vri branches of m68k-atari-mint-gcc
URLS = \
	https://ftp.gnu.org/gnu/binutils/$(BINUTILS).tar.xz \
	https://ftp.gnu.org/gnu/gmp/$(GMP).tar.xz \
	https://ftp.gnu.org/gnu/mpfr/$(MPFR).tar.xz \
	https://github.com/freemint/m68k-atari-mint-gcc/archive/$(GCC44).tar.gz \
	https://github.com/freemint/m68k-atari-mint-gcc/archive/$(GCC33).tar.gz \
	https://github.com/freemint/mintlib/archive/$(MINTLIB).tar.gz \
	https://github.com/freemint/fdlibm/archive/$(FDLIBM).tar.gz

GCC_OLD_HOST = -std=gnu89 -fgnu89-inline -fcommon -w

all: $(PREFIX)/.binutils $(PREFIX)/.sysroot $(PREFIX)/.gcc44 $(PREFIX)/.gcc33

$(DOWNLOAD)/.ok: SHA256SUMS
	mkdir -p $(DOWNLOAD)
	cd $(DOWNLOAD) && for u in $(URLS); do \
		f=$$(basename $$u); \
		case $$u in */archive/*) f=$$(echo $$u | cut -d/ -f5)-$$f;; esac; \
		[ -f $$f ] || { curl -fL -o $$f.part $$u && mv $$f.part $$f; } || exit 1; \
	done
	cd $(DOWNLOAD) && sha256sum -c $(CURDIR)/SHA256SUMS
	touch $@

$(PREFIX)/.binutils: $(DOWNLOAD)/.ok patches/binutils-2.45-m68k-old-gas.patch
	rm -rf $(BUILD)/$(BINUTILS) $(BUILD)/binutils
	mkdir -p $(BUILD)/binutils
	tar xf $(DOWNLOAD)/$(BINUTILS).tar.xz -C $(BUILD)
	patch -d $(BUILD)/$(BINUTILS) -p1 < patches/binutils-2.45-m68k-old-gas.patch
	cd $(BUILD)/binutils && $(BUILD)/$(BINUTILS)/configure --target=m68k-elf --prefix=$(PREFIX) \
		--disable-nls --disable-werror --disable-gdb --disable-gdbserver --disable-sim \
		--disable-gprof --disable-gprofng --without-zstd --disable-plugins
	$(MAKE) -C $(BUILD)/binutils -j$(JOBS) all-gas all-ld all-binutils
	$(MAKE) -C $(BUILD)/binutils install-gas install-ld install-binutils
	touch $@

# headers only: MiNTLib + fdlibm (math.h)
$(PREFIX)/.sysroot: $(DOWNLOAD)/.ok patches/mintlib-2012-compat.patch
	rm -rf $(BUILD)/mintlib-$(MINTLIB) $(BUILD)/fdlibm-$(FDLIBM) $(PREFIX)/sys-root
	mkdir -p $(PREFIX)/sys-root/usr
	tar xzf $(DOWNLOAD)/mintlib-$(MINTLIB).tar.gz -C $(BUILD)
	tar xzf $(DOWNLOAD)/fdlibm-$(FDLIBM).tar.gz -C $(BUILD)
	cp -r $(BUILD)/mintlib-$(MINTLIB)/include $(PREFIX)/sys-root/usr/include
	cp -r $(BUILD)/fdlibm-$(FDLIBM)/include/. $(PREFIX)/sys-root/usr/include/
	cd $(PREFIX)/sys-root/usr/include && \
		sed -e 's/@MAJOR@/0/' -e 's/@MINOR@/60/' -e 's/@REVISION@/1/' -e 's/@BETATAG@/""/' \
			features.h.in > features.h && \
		sed -e 's/@LINKER_TYPE@/GNU/' linker.h.in > linker.h
	patch -d $(PREFIX)/sys-root/usr/include -p1 < patches/mintlib-2012-compat.patch
	touch $@

$(BUILD)/hostlibs/.ok: $(DOWNLOAD)/.ok
	rm -rf $(BUILD)/$(GMP) $(BUILD)/$(MPFR) $(BUILD)/gmp $(BUILD)/mpfr $(BUILD)/hostlibs
	mkdir -p $(BUILD)/gmp $(BUILD)/mpfr
	tar xf $(DOWNLOAD)/$(GMP).tar.xz -C $(BUILD)
	tar xf $(DOWNLOAD)/$(MPFR).tar.xz -C $(BUILD)
	cd $(BUILD)/gmp && CC="$(HOSTCC) -std=gnu17" $(BUILD)/$(GMP)/configure \
		--prefix=$(BUILD)/hostlibs --disable-shared --enable-static
	$(MAKE) -C $(BUILD)/gmp -j$(JOBS) install
	cd $(BUILD)/mpfr && CC="$(HOSTCC) -std=gnu17" $(BUILD)/$(MPFR)/configure \
		--prefix=$(BUILD)/hostlibs --with-gmp=$(BUILD)/hostlibs --disable-shared --enable-static
	$(MAKE) -C $(BUILD)/mpfr -j$(JOBS) install
	touch $@

# driver + cc1 only, 64-bit host; output is assembled by bin/m68k-as
$(PREFIX)/.gcc44: $(BUILD)/hostlibs/.ok $(PREFIX)/.binutils $(PREFIX)/.sysroot patches/gcc-4.4.3-mint-pr39531.patch
	rm -rf $(BUILD)/m68k-atari-mint-gcc-$(GCC44) $(BUILD)/gcc44 $(PREFIX)/gcc-4.4.3
	mkdir -p $(BUILD)/gcc44
	tar xzf $(DOWNLOAD)/m68k-atari-mint-gcc-$(GCC44).tar.gz -C $(BUILD)
	patch -d $(BUILD)/m68k-atari-mint-gcc-$(GCC44) -p1 < patches/gcc-4.4.3-mint-pr39531.patch
	cd $(BUILD)/gcc44 && CC="$(HOSTCC) $(GCC_OLD_HOST)" CXX="g++ -std=gnu++98 -w" \
		$(BUILD)/m68k-atari-mint-gcc-$(GCC44)/configure --target=m68k-atari-mint \
		--prefix=$(PREFIX)/gcc-4.4.3 --with-gmp=$(BUILD)/hostlibs --with-mpfr=$(BUILD)/hostlibs \
		--with-as=$(PREFIX)/bin/m68k-elf-as --with-ld=$(PREFIX)/bin/m68k-elf-ld \
		--with-gnu-as --with-gnu-ld --enable-languages=c --disable-nls --disable-multilib \
		--disable-libssp --disable-shared --disable-bootstrap --disable-threads --without-headers \
		--with-native-system-header-dir=/usr/include --with-sysroot=$(PREFIX)/sys-root \
		MAKEINFO=true
	$(MAKE) -C $(BUILD)/gcc44 -j$(JOBS) MAKEINFO=true all-gcc
	$(MAKE) -C $(BUILD)/gcc44 MAKEINFO=true install-gcc
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
