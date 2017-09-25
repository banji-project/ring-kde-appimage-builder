# This Dockerfile creates a static Ring-KDE binary.
#
# Usually, Ring is a client/server application, but this is problematic
# for portable binaries. This is replaced here by a Qt compatibility
# layer on top of the Ring-Daemon library. This way, it is possible
# to run a system version of Ring (with or without the Gnome client)
# *AND* the portable Ring-KDE on the same system without issues.
#
# This appimage also tries to use the static version of Qt and KF5
# as much as possible to avoid accidently using system libraries. As
# Qt isn't ABI compatible, this solves some runtime issues on some
# weirdly configured systems. It also, when used along with -lto,
# reduces the image size and startup time.
FROM ubuntu:14.04
MAINTAINER Emmanuel Lepage-Vallee (elv1313@gmail.com)

RUN apt update && apt upgrade -y

# Those are the Ring daemon build system dependencies
RUN apt install build-essential curl pkg-config autoconf cmake3 yasm \
 libtool git wget -y

# Since early 2017, Ring depends on C++14
RUN echo deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu trusty main >> /etc/apt/sources.list
RUN echo deb-src http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu trusty main >> /etc/apt/sources.list
RUN apt update

RUN apt remove gcc g++ -y
RUN apt install gcc-7 g++-7 -y --force-yes

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 60 \
 --slave /usr/bin/g++ g++ /usr/bin/g++-7

# Those are the QtQuick OpenGL dependencies
RUN apt install libgl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libglu-dev\
 libglu1-mesa-dev freeglut3 libgl1-mesa-dev libwayland-egl1-mesa python \
 libssl-dev -y

# Download Qt in order to build a minimal library
RUN wget http://qt.mirrors.tds.net/qt/archive/qt/5.8/5.8.0/single/qt-everywhere-opensource-src-5.8.0.tar.gz &&\
 tar -zxvf qt-everywhere-opensource-src-5.8.0.tar.gz

# Build a static Qt package with as little system dependencies as
# possible
RUN cd qt-e* &&\
  ./configure -v -release -opensource -confirm-license -reduce-exports -ssl \
   -qt-xcb -feature-accessibility -opengl desktop  -static -nomake examples \
   -nomake tests -skip qtwebengine -skip qtscript -skip qt3d -skip qtandroidextras \
   -skip qtwebview -skip qtwebsockets -skip qtdoc -skip qtcharts \
   -skip qtdatavis3d -skip qtgamepad -skip qtmultimedia -skip qtsensors \
   -skip qtserialbus -skip qtserialport -skip qtwebchannel -skip qtwayland \
   -prefix /opt/usr -no-glib -qt-zlib

# Build Qt, this is long
RUN cd qt-e* && make -j8
RUN cd qt-e* && make install

# Not very clean, but running tests in this environment hits a lot of
# bugs due to the unexpected static linkage.
RUN rm /opt/usr/lib/cmake/Qt5Test/Qt5TestConfig.cmake

# Set some variable before bootstrapping KF5
ENV Qt5_DIR=/opt/usr/
ENV CMAKE_PREFIX_PATH=/opt/usr/
RUN QT_INSTALL_PREFIX=/opt/usr/

# Begin building KF5
RUN apt install gperf gettext libxcb-keysyms1-dev libxrender-dev \
 flex bison -y
RUN git clone https://anongit.kde.org/extra-cmake-modules
RUN cd extra-cmake-modules && mkdir build && cd build && cmake .. \
 -DCMAKE_INSTALL_PREFIX=/ && make -j8 install

RUN mkdir -p /bootstrap/build

ADD CMakeLists.txt /bootstrap/CMakeLists.txt
ADD CMakeRingWrapper.txt.in /bootstrap/CMakeRingWrapper.txt.in
ADD CMakeWrapper.txt.in /bootstrap/CMakeWrapper.txt.in
ADD patches /bootstrap/patches

RUN mkdir /opt/ring-kde.AppDir -p

# This is necessary to build Ring with Pulse and video accel
# **WARNING** This has to be executed AFTER Qt has been installed to
# avoid poluting the system with versions of those packages
RUN apt install libvdpau-dev libva-dev gettext autopoint libasound-dev \
 libpulse-dev libudev-dev wget libdbus-1-dev -y

# Wahtever makes it happy
RUN ln -s /usr/bin/gcc /usr/bin/cc

# Fetch the ring library (without the daemon)
RUN git clone https://github.com/savoirfairelinux/ring-daemon --progress --verbose
RUN cd ring-daemon && git apply /bootstrap/patches/ring-daemon.patch
RUN mkdir -p ring-daemon/contrib/native && cd ring-daemon/contrib/native &&\
 ../bootstrap --disable-dbus-cpp --enable-vorbis --enable-ogg \
   --enable-opus --enable-zlib&& make fetch-all

# Build all the static dependencies
RUN cd ring-daemon/contrib/native && make -j8

# Compile the daemon. Pulse is disabled for now because it pulls
# too many dependencies are cause libring to link to them...
RUN cd ring-daemon &&  ./autogen.sh && ./configure --without-dbus \
 --enable-static --without-pulse --disable-vdpau --disable-vaapi \
 --disable-videotoolbox --disable-vda --disable-accel \
 --prefix=/opt/ring-kde.AppDir && make -j

# Build all the frameworks and prepare Ring-KDE
RUN cd /bootstrap/build && cmake .. -CMAKE_INSTALL_PREFIX=/opt/ring-kde.AppDir\
 -Wno-dev || echo Ignore

# Add the appimages
RUN apt install libfuse2 -y
RUN wget "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
RUN chmod a+x appimagetool-x86_64.AppImage

RUN cp /bootstrap/build/ring-kde/ring-kde/data/*.desktop /opt/ring*/
RUN cp /bootstrap/build/ring-kde/ring-kde/data/icons/sc-apps-ring-kde.svgz \
  /opt/ring-kde.AppDir/ring-kde.svgz

CMD cd cd /bootstrap/build && make -j8 install && /appimagetool-x86_64.AppImage \
  /opt/ring-kde.AppDir/ ring-kde.appimage
