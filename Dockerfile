FROM gentoo/stage3-amd64
RUN emerge --sync

# Force the older GLibC 2.23 as the Ubuntu 16.04 is the oldest supported
# desktop Linux for 32bit ARM
RUN rm -rf /usr/portage/sys-libs/glibc
RUN mkdir /usr/portage/sys-libs/glibc
ADD glibc /usr/portage/sys-libs/glibc

# Setup the cross compiling toolchain (glibc, gcc, mpc, mpfr, binutils)
RUN emerge crossdev
RUN mkdir /usr/local/portage-crossdev
ADD crossdev.conf /etc/portage/repos.conf/crossdev.conf

# https://bugs.gentoo.org/558774
RUN USE="xml" emerge python x11-proto/xcb-proto
RUN crossdev -v -t armv7a-hardfloat-linux-gnueabi

# https://bugs.gentoo.org/641902
RUN mkdir /usr/armv7a-hardfloat-linux-gnueabi/usr/include/X11/ -p
RUN ln -s /usr/armv7a-hardfloat-linux-gnueabi/usr/include/X11/ /usr/include/X11

# For LTO to work at all
RUN binutils-config --linker ld.gold

# Select the Gentoo desktop profile for ARMv7, eventually create a Neon one
RUN rm -rf /usr/armv7a-hardfloat-linux-gnueabi/etc/portage/make.profile
RUN ln -s /usr/portage/profiles/default/linux/arm/17.0/armv7a/desktop/ /usr/armv7a-hardfloat-linux-gnueabi/etc/portage/make.profile

#TODO remove, it's useless
RUN emerge x11-proto/glproto

RUN mkdir /usr/armv7a-hardfloat-linux-gnueabi/etc/portage/package.mask
RUN mkdir /usr/armv7a-hardfloat-linux-gnueabi/etc/portage/package.unmask
RUN echo '>=sys-libs/glibc-2.24' >> /usr/armv7a-hardfloat-linux-gnueabi/etc/portage/package.mask/mask
RUN echo '<=sys-libs/glibc-2.24' >> /usr/armv7a-hardfloat-linux-gnueabi/etc/portage/package.unmask/unmask

# https://bugs.gentoo.org/642038
ADD ./make.conf /usr/armv7a-hardfloat-linux-gnueabi/etc/portage/

# In theory, I should emerge @system first, but it's slow
# https://bugs.gentoo.org/641882
# https://bugs.gentoo.org/641886
RUN armv7a-hardfloat-linux-gnueabi-emerge @system || echo Ignore

# https://bugs.gentoo.org/641918
RUN USE="-zlib -bzip2" armv7a-hardfloat-linux-gnueabi-emerge libpcre file

# https://bugs.gentoo.org/641934
RUN armv7a-hardfloat-linux-gnueabi-emerge autoconf-archive

# https://bugs.gentoo.org/584052
# Fuck this one, I don't need gpg to work adding --build=arm-unknown-linux-gnueabi
# to the ebuild make it compile garbage. Their build system is broken

RUN USE="-pam -consolekit" armv7a-hardfloat-linux-gnueabi-emerge sys-apps/dbus --root-deps -1 --quiet --keep-going || echo Ignore

RUN armv7a-hardfloat-linux-gnueabi-emerge @system --update --deep --quiet --keep-going|| echo Ignore

RUN USE="-zlib -bzip2" armv7a-hardfloat-linux-gnueabi-emerge @system --update || echo Ignore
RUN armv7a-hardfloat-linux-gnueabi-emerge @system || echo Ignore || echo Ignore
RUN armv7a-hardfloat-linux-gnueabi-emerge @system --root-deps --deep --update || echo Ignore

RUN armv7a-hardfloat-linux-gnueabi-emerge openssl sys-libs/zlib --quiet

# https://bugs.gentoo.org/558774
RUN armv7a-hardfloat-linux-gnueabi-emerge -1 xcb-proto libxslt x11-misc/util-macros --root-deps || echo Ignore
RUN armv7a-hardfloat-linux-gnueabi-emerge -1 --resume --skipfirst || echo Ignore
RUN armv7a-hardfloat-linux-gnueabi-emerge -1 xcb-proto  || echo Ignore

# https://bugs.gentoo.org/642330
RUN sed -i 's/local myeconfargs=(/local myeconfargs=( --host=${CHOST} --disable-malloc0returnsnull/' /usr/portage/eclass/xorg-2.eclass
RUN armv7a-hardfloat-linux-gnueabi-emerge  x11-libs/libXrender

RUN armv7a-hardfloat-linux-gnueabi-emerge -1 libxcb

# https://bugs.gentoo.org/641904
RUN armv7a-hardfloat-linux-gnueabi-emerge mesa --quiet --root-deps || echo Ignore
RUN armv7a-hardfloat-linux-gnueabi-emerge --resume --skipfirst

RUN wget http://qt.mirrors.tds.net/qt/archive/qt/5.9/5.9.3/single/qt-everywhere-opensource-src-5.9.3.tar.xz
RUN tar -xpvf qt-everywhere-opensource-src-5.9.3.tar.xz

# Replace the default performance Qt flags for portability ones
RUN sed 's/-O3/-Os/' -i /qt-everywhere-opensource-src-5.9.3/qtbase/mkspecs/common/qcc-base.conf
RUN sed 's/-O2/-Os/' -i /qt-everywhere-opensource-src-5.9.3/qtbase/mkspecs/common/qcc-base.conf
RUN sed 's/-O3/-Os/' -i /qt-everywhere-opensource-src-5.9.3/qtbase/mkspecs/common/gcc-base.conf
RUN sed 's/-O2/-Os/' -i /qt-everywhere-opensource-src-5.9.3/qtbase/mkspecs/common/gcc-base.conf
RUN echo 'QMAKE_CXXFLAGS -=-O3' >> /qt-everywhere-opensource-src-5.9.3/qtbase/mkspecs/linux-g++/qmake.conf
RUN echo 'QMAKE_CXXFLAGS_RELEASE -=-O3' >> /qt-everywhere-opensource-src-5.9.3/qtbase/mkspecs/linux-g++/qmake.conf
RUN echo 'QMAKE_CXXFLAGS -=-O2' >> /qt-everywhere-opensource-src-5.9.3/qtbase/mkspecs/linux-g++/qmake.conf
RUN echo 'QMAKE_CXXFLAGS_RELEASE -=-O2' >> /qt-everywhere-opensource-src-5.9.3/qtbase/mkspecs/linux-g++/qmake.conf
RUN echo 'QMAKE_CXXFLAGS=-Os' >> /qt-everywhere-opensource-src-5.9.3/qtbase/mkspecs/linux-g++/qmake.conf
RUN echo 'QMAKE_CXXFLAGS_RELEASE=-Os' >> /qt-everywhere-opensource-src-5.9.3/qtbase/mkspecs/linux-g++/qmake.conf
RUN find /qt-everywhere-opensource-src-5.9.3/ | xargs grep O3 2> /dev/null \
 | grep -v xml | grep -v Binary 2> /dev/null | cut -f1 -d ':' \
 | grep -E '\.(conf|mk|sh|am|in)$' | xargs sed -i 's/O3/Os/'

# Add the Plsama mobile LTO AppImage device specific files
ADD qmake.conf /
ADD qplatformdefs.h /
RUN cd /qt-e* && mkdir qtbase/mkspecs/devices/linux-plasma-mobile-armv7a-hardfloat/
RUN cd /qt-e* && mv /qmake.conf qtbase/mkspecs/devices/linux-plasma-mobile-armv7a-hardfloat/
RUN cd /qt-e* && mv /qplatformdefs.h qtbase/mkspecs/devices/linux-plasma-mobile-armv7a-hardfloat/

# Build a static Qt package with as little system dependencies as
# possible
RUN cd qt-e* &&\
  ./configure -v -release -opensource -confirm-license \
    -ssl -qt-xcb -qt-xkbcommon -feature-accessibility\
    -opengl es2 -static -nomake examples -nomake tests -skip qtwebengine\
     -skip qtscript -skip qt3d -skip qtandroidextras -skip qtwebview -skip \
     qtwebsockets -skip qtdoc -skip qtcharts -skip qtdatavis3d -skip qtgamepad \
     -skip qtmultimedia -skip qtsensors -skip qtserialbus -skip qtserialport \
     -skip qtwebchannel -skip qtwayland -prefix /opt/usr -no-glib -qt-zlib \
     -qt-freetype -ltcg -device linux-plasma-mobile-armv7a-hardfloat \
     -device-option CROSS_COMPILE=/usr/bin/armv7a-hardfloat-linux-gnueabi-

#PKG_CONFIG_SYSROOT_DIR="/usr/armv7a-hardfloat-linux-gnueabi/" PKG_CONFIG_LIBDIR="/usr/armv7a-hardfloat-linux-gnueabi/usr/lib/pkgconfig/" ./configure -v -release -opensource -confirm-license   -no-xcb -no-xkbcommon-x11  -ssl  -feature-accessibility    -opengl es2 -static -nomake examples -nomake tests -skip qtwebengine     -skip qtscript -skip qt3d -skip qtandroidextras -skip qtwebview -skip      qtwebsockets -skip qtdoc -skip qtcharts -skip qtdatavis3d -skip qtgamepad      -skip qtmultimedia -skip qtsensors -skip qtserialbus -skip qtserialport      -skip qtwebchannel  -prefix /opt/usr -no-glib -qt-zlib      -qt-freetype -ltcg -device linux-plasma-mobile-armv7a-hardfloat      -device-option CROSS_COMPILE=/usr/bin/armv7a-hardfloat-linux-gnueabi-  -qpa eglfs -libinput -no-xkbcommon-evdev -no-evdev -no-mtdev -force-pkg-config  -skip qtlocation

RUN cd qt-e* && make -j8 install || echo ignore

# Not very clean, but running tests in this environment hits a lot of
# bugs due to the unexpected static linkage.
RUN rm /opt/usr/lib/cmake/Qt5Test/Qt5TestConfig.cmake

# Install the KF5 (host) dependencies
RUN USE="-webdav -perl -python -nls -gnutls -readline -ncurses -cxx -tls-heartbeat -seccomp" emerge dev-vcs/git cmake --quiet

# Begin building KF5 (target) dependencies
RUN USE="-gpg -pcre -perl -python -threads -webdav" armv7a-hardfloat-linux-gnueabi-emerge  gperf gettext \
 flex bison x11-libs/xcb-util-keysyms \
 media-libs/alsa-lib --quiet

# Set some variable before bootstrapping KF5
ENV Qt5_DIR=/opt/usr/
ENV CMAKE_PREFIX_PATH=/opt/usr/
RUN QT_INSTALL_PREFIX=/opt/usr/

#TODO report a bug
RUN ln -s /usr/armv7a-hardfloat-linux-gnueabi/usr/include/GLES2\
   /usr/armv7a-hardfloat-linux-gnueabi/usr/include/GLES2/

RUN git clone https://anongit.kde.org/extra-cmake-modules
RUN cd extra-cmake-modules && mkdir build && cd build && cmake .. \
 -DCMAKE_INSTALL_PREFIX=/usr/ && make -j8 install

RUN mkdir -p /bootstrap/build

RUN mkdir /opt/ring-kde.AppDir -p

# Fetch the ring library (without the daemon)
RUN git clone https://github.com/savoirfairelinux/ring-daemon --progress --verbose

# Add the patch now as the daemon use them
ADD patches /bootstrap/patches

# Compile the GNU Ring.cx library and dependencies
RUN cd ring-daemon && git apply /bootstrap/patches/ring-daemon.patch
RUN mkdir -p ring-daemon/contrib/x86_64-pc-linux-gnu/
RUN rm -rf ring-daemon/contrib/x86_64-pc-linux-gnu/lib || echo Ok
RUN ln -s /usr/armv7a-hardfloat-linux-gnueabi/usr/lib ring-daemon/contrib/x86_64-pc-linux-gnu/lib
#RUN emerge -C curl
RUN mkdir -p ring-daemon/contrib/native && cd ring-daemon/contrib/native &&\
 CXXFLAGS=" -ffunction-sections -fdata-sections  -Wno-error=unused-result -Wno-unused-result -Os" \
 CFLAGS=" -ffunction-sections -fdata-sections  -Wno-error=unused-result -Wno-unused-result -Os" ../bootstrap --disable-dbus-cpp --enable-vorbis --enable-ogg \
   --enable-opus --enable-zlib --enable-uuid --enable-uuid --enable-pcre --build=armv7a-hardfloat-linux-gnueabi --host=x86_64-pc-linux-gnu

# Fetch watever works to we don't need to refetch everything when a mirror is down
RUN cd ring-daemon/contrib/native && make fetch-all -j8 || echo Ignore
RUN cd ring-daemon/contrib/native && make fetch-all -j8


#RUN emerge net-misc/curl

# This one is because libtool do stupid things to CXXFLAGS, this is actually
# the official "fix"
# https://www.gnu.org/software/libtool/manual/html_node/Stripped-link-flags.html
ENV CXX="armv7a-hardfloat-linux-gnueabi-g++ -static-libgcc -static-libstdc++"

ENV CC=armv7a-hardfloat-linux-gnueabi-gcc
ENV AR="/usr/x86_64-pc-linux-gnu/armv7a-hardfloat-linux-gnueabi/gcc-bin/7.2.0/armv7a-hardfloat-linux-gnueabi-gcc-ar"
ENV NM="/usr/x86_64-pc-linux-gnu/armv7a-hardfloat-linux-gnueabi/gcc-bin/7.2.0/armv7a-hardfloat-linux-gnueabi-gcc-nm"
ENV RANLIB="/usr/x86_64-pc-linux-gnu/armv7a-hardfloat-linux-gnueabi/gcc-bin/7.2.0/armv7a-hardfloat-linux-gnueabi-gcc-ranlib"
ENV LD="/usr/bin/armv7a-hardfloat-linux-gnueabi-ld.gold"
ENV AS=/usr/x86_64-pc-linux-gnu/armv7a-hardfloat-linux-gnueabi/binutils-bin/2.29.1/as
ENV ABI=32
ENV PKG_CONFIG=armv7a-hardfloat-linux-gnueabi-pkg-config
ENV CFLAGS="-Os -march=armv7-a -pipe -fomit-frame-pointer -ffunction-sections \
    -fdata-sections -Wl,--gc-sections -Wl,--strip-all \
    -L/usr/armv7a-hardfloat-linux-gnueabi/lib/ \
    -L/usr/armv7a-hardfloat-linux-gnueabi/usr/lib/"
ENV CXXFLAGS="${CFLAGS} -static-libgcc -static-libstdc++"
#ENV LDFLAGS="-static-libstdc++"
# -fuse-linker-plugin --gc-sections --strip-all --as-needed"

# Really, don't ask, blame ffmpeg
RUN ln -s /ring-daemon/ /usr/armv7a-hardfloat-linux-gnueabi/

#HACK Fix msgpack until the PR is merged
RUN cd ring-daemon/contrib/native && make msgpack || echo Ignore2
RUN sed -i 's/-Werror//' /ring-daemon/contrib/native/msgpack/CMakeLists.txt
RUN sed -i 's/-Werror//' /ring-daemon/contrib/native/msgpack/CMakeLists.txt
RUN sed -i 's/-O3/-Os/' /ring-daemon/contrib/native/msgpack/CMakeLists.txt
RUN sed -i 's/-O3/-Os/' /ring-daemon/contrib/native/msgpack/CMakeLists.txt

# Cross compile hack
RUN cd ring-daemon/contrib/native && CXXFLAGS="-Wno-error=unused-result \
 -Wno-unused-result -Os -ffunction-sections -fdata-sections " \
  CFLAGS="-Os -Wno-error=unused-result -Wno-unused-result -ffunction-sections\
  -fdata-sections " make -j8 || echo ignore2 #HACK
#RUN cp /usr/share/libtool/build-aux/config.guess /ring-daemon/contrib/native/uuid/
#RUN cp /usr/share/libtool/build-aux/config.sub /ring-daemon/contrib/native/uuid/

# Some build system ignure $LD and use `ld` directly, it wont work
RUN rm /usr/libexec/gcc/armv7a-hardfloat-linux-gnueabi/ld
RUN cp /usr/libexec/gcc/armv7a-hardfloat-linux-gnueabi/ld.gold \
   /usr/libexec/gcc/armv7a-hardfloat-linux-gnueabi/ld

#HACK!!!!!
RUN cd ring-daemon/contrib/native &&\
 ../bootstrap --disable-dbus-cpp --enable-vorbis --enable-ogg \
   --enable-opus --enable-zlib --enable-uuid --enable-uuid \
   --host=x86_64-pc-linux-gnu --build=armv7a-hardfloat-linux-gnueabi \
   && make fetch-all

# Build all the static dependencies
RUN cd ring-daemon/contrib/native && make -j8 || echo Let it fail
RUN cd ring-daemon/contrib/native && make -j8

# Compile the daemon. Pulse is disabled for now because it pulls
# too many dependencies are cause libring to link to them...
RUN cd ring-daemon &&  ./autogen.sh && ./configure --without-dbus \
 --enable-static --without-pulse --disable-vdpau --disable-vaapi \
 --disable-videotoolbox --disable-vda --disable-accel --disable-shared \
 --prefix=/opt/ring-kde.AppDir --host=x86_64-pc-linux-gnu \
 --build=armv7a-hardfloat-linux-gnueabi && make -j8

# TODO report bug
#ADD autotools-multilib.eclass /usr/portage/eclass/
#RUN armv7a-hardfloat-linux-gnueabi-emerge virtual/glu

# Only add the file after the Daemon is built to speedup image creation
ADD CMakeLists.txt /bootstrap/CMakeLists.txt
ADD CMakeRingWrapper.txt.in /bootstrap/CMakeRingWrapper.txt.in
ADD CMakeWrapper.txt.in /bootstrap/CMakeWrapper.txt.in
ADD cmake /bootstrap/cmake

# Build all the frameworks and prepare Ring-KDE
RUN cd /bootstrap/build && CXXFLAGS="" LDFLAGS="" cmake .. -DCMAKE_INSTALL_PREFIX=/opt/ring-kde.AppDir\
 -DCMAKE_BUILD_TYPE=Release -DDISABLE_KDBUS_SERVICE=1 \
 -DRING_BUILD_DIR=/ring-daemon/src/ -Dring_BIN=/ring-daemon/src/.libs/libring.a -Wno-dev || echo Ignore

#HACK patches in the merging pipeline
RUN rm /bootstrap/build/kirigami/done
RUN cd /bootstrap/build/kirigami/kirigami; git reset --hard; git remote add elv13 ssh://lepagee@10.10.10.108:/home/lepagee/archive/kirigami
RUN cd /bootstrap/build/qqc2-desktop-style/qqc2-desktop-style; git remote add elv13 ssh://lepagee@10.10.10.108:/home/lepagee/archive/qqc2-desktop-style

# wayland-scanner needs to be compiled with the host compiler
RUN emerge dev-libs/wayland meson dev-util/ninja
RUN USE="static-libs" armv7a-hardfloat-linux-gnueabi-emerge libinput #x11-libs/libxkbcommon
RUN armv7a-hardfloat-linux-gnueabi-emerge dev-libs/wayland dev-libs/wayland-protocols

# Give it a chance, without this, it will work on very few devices
RUN git clone https://github.com/Halium/android-headers.git
RUN git clone https://github.com/libhybris/libhybris.git
RUN cd libhybris; ./configure --prefix=/usr/armv7a-hardfloat-linux-gnueabi/ --host=armv7a-hardfloat-linux-gnueabi --build=x86_64-pc-linux-gnu --with-android-headers=/android-headers/

