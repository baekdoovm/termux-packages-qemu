TERMUX_PKG_HOMEPAGE=https://www.qemu.org
TERMUX_PKG_DESCRIPTION="A generic and open source machine emulator and virtualizer (Custom SDL/VNC)"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="1:8.2.5"
TERMUX_PKG_SRCURL="https://download.qemu.org/qemu-${TERMUX_PKG_VERSION:2}.tar.xz"
TERMUX_PKG_SHA256=da5fcffc32762820568b828ed430a728864d34d50b6d2f30358597760cbb0523
TERMUX_PKG_DEPENDS="alsa-lib, dtc, gdk-pixbuf, glib, jack2, gtk3, libbz2, libcairo, libcurl, libdw, libepoxy, libgmp, libgnutls, libiconv, libjpeg-turbo, liblzo, libnettle, libnfs, libpixman, libpng, libslirp, libspice-server, libssh, libusb, libusbredir, libx11, mesa, ncurses, pulseaudio, qemu-common, resolv-conf, sdl2 | sdl2-compat, sdl2-image, virglrenderer, zlib, zstd"
TERMUX_PKG_BUILD_DEPENDS="libtasn1"
TERMUX_PKG_ANTI_BUILD_DEPENDS="sdl2-compat"

TERMUX_PKG_RM_AFTER_INSTALL="
bin/elf2dmp
bin/qemu-edid
bin/qemu-ga
bin/qemu-img
bin/qemu-io
bin/qemu-keymap
bin/qemu-nbd
bin/qemu-pr-helper
bin/qemu-storage-daemon
include/*
libexec/qemu-bridge-helper
share/applications
share/doc
share/icons
share/man/man1/qemu-img.1*
share/man/man1/qemu-storage-daemon.1*
share/man/man1/qemu.1*
share/man/man7
share/man/man8/qemu-ga.8*
share/man/man8/qemu-nbd.8*
share/man/man8/qemu-pr-helper.8*
share/qemu
"

TERMUX_PKG_CONFLICTS="qemu-system-x86_64, qemu-system-x86_64-headless, qemu-system-x86-64-headless"
TERMUX_PKG_REPLACES="qemu-system-x86_64, qemu-system-x86_64-headless, qemu-system-x86-64-headless"
TERMUX_PKG_PROVIDES="qemu-system-x86_64"
TERMUX_PKG_EXCLUDED_ARCHES="arm, i686"
TERMUX_PKG_BUILD_IN_SRC=true

termux_step_pre_configure() {
	# aarch64 세트점프 패치 (Termux NDK 호환용)
	if [ $TERMUX_ARCH = "aarch64" ]; then
		rm -f $TERMUX_PKG_BUILDDIR/_lib
		mkdir -p $TERMUX_PKG_BUILDDIR/_lib

		cd $TERMUX_PKG_BUILDDIR
		mkdir -p _setjmp-aarch64
		pushd _setjmp-aarch64
		mkdir -p private
		local s
		for s in $TERMUX_PKG_BUILDER_DIR/setjmp-aarch64/{setjmp.S,private-*.h}; do
			local f=$(basename ${s})
			cp ${s} ./${f/-//}
		done
		$CC $CFLAGS $CPPFLAGS -I. setjmp.S -c
		$AR cru $TERMUX_PKG_BUILDDIR/_lib/libandroid-setjmp.a setjmp.o
		popd

		LDFLAGS+=" -L$TERMUX_PKG_BUILDDIR/_lib -l:libandroid-setjmp.a"
	fi
}

termux_step_configure() {
	termux_setup_ninja

	if [ "$TERMUX_ARCH" = "i686" ]; then
		LDFLAGS+=" -latomic"
	fi

	# 요청한 타겟만 지정 (x86_64, i386, aarch64, ppc, ppc64)
	local QEMU_TARGETS=""
	QEMU_TARGETS+="aarch64-softmmu,"
	QEMU_TARGETS+="i386-softmmu,"
	QEMU_TARGETS+="ppc-softmmu,"
	QEMU_TARGETS+="ppc64-softmmu,"
	QEMU_TARGETS+="x86_64-softmmu"

	CFLAGS+=" $CPPFLAGS"
	CXXFLAGS+=" $CPPFLAGS"
	LDFLAGS+=" -landroid-shmem -llog"

	./configure \
		--prefix="$TERMUX_PREFIX" \
		--cross-prefix="${TERMUX_HOST_PLATFORM}-" \
		--host-cc="gcc" \
		--cc="$CC" \
		--cxx="$CXX" \
		--objcc="$CC" \
		--disable-stack-protector \
		--smbd="$TERMUX_PREFIX/bin/smbd" \
		--enable-coroutine-pool \
		--audio-drv-list=pa,sdl \
		--enable-trace-backends=nop \
		--disable-guest-agent \
		--enable-gnutls \
		--enable-nettle \
		--enable-sdl \
		--enable-sdl-image \
		--enable-gtk \
		--enable-opengl \
		--enable-virglrenderer \
		--disable-vte \
		--enable-curses \
		--enable-iconv \
		--enable-vnc \
		--disable-vnc-sasl \
		--enable-vnc-jpeg \
		--enable-png \
		--disable-xen \
		--disable-xen-pci-passthrough \
		--enable-virtfs \
		--enable-curl \
		--enable-fdt=system \
		--enable-kvm \
		--disable-hvf \
		--disable-whpx \
		--disable-libnfs \
		--enable-lzo \
		--disable-snappy \
		--enable-bzip2 \
		--disable-lzfse \
		--disable-seccomp \
		--enable-libssh \
		--enable-bochs \
		--enable-cloop \
		--enable-dmg \
		--enable-parallels \
		--enable-qed \
		--enable-slirp \
		--enable-spice \
		--enable-libusb \
		--enable-usb-redir \
		--disable-vhost-user \
		--disable-vhost-user-blk-server \
		--target-list="$QEMU_TARGETS"
}

termux_step_post_make_install() {
	local i
	# 심볼릭 링크 생성도 빌드한 타겟에 맞춰 수정
	for i in aarch64 i386 ppc ppc64 x86_64; do
		ln -sfr \
			"${TERMUX_PREFIX}"/share/man/man1/qemu.1 \
			"${TERMUX_PREFIX}"/share/man/man1/qemu-system-${i}.1
	done
}
