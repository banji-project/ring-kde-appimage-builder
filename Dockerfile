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

# Those are the Ring daemon build system dependencies
RUN apt install build-essential curl pkg-config autoconf cmake yasm libtool

# This is necessary to build Ring with Pulse and video accel
RUN apt install libvdpau-dev libva-dev gettext autopoint libasound-dev \
 libpulse-dev libudev-dev wget libdbus-1-dev -y

# Install the ring library (without the daemon)
RUN git clone https://github.com/savoirfairelinux/ring-daemon
RUN mkdir -p ring-daemon/contrib/native && cd ring-daemon/contrib/native &&\
 ../bootstrap --disable-dbus-cpp htop&& make -j

# Compile the daemon. Pulse is disabled for now because it pulls
# too many dependencies are cause libring to link to them...
RUN cd ring-daemon &&  ./autogen.sh && ./configure --without-dbus \
 --enable-static --without-pulse && make -j

# Those are the QtQuick OpenGL dependencies
RUN apt install libgl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libglu-dev\
 libglu1-mesa-dev freeglut3 libgl1-mesa-dev libwayland-egl1-mesa python -y

# Download Qt in order to build a minimal library
RUN wget http://qt.mirrors.tds.net/qt/archive/qt/5.8/5.8.0/single/qt-everywhere-opensource-src-5.8.0.tar.gz &&\
 tar -zxvf qt-everywhere-opensource-src-5.8.0.tar.gz

# Build a static Qt package with as little system dependencies as
# possible
RUN cd qt-e* && 


./configure -v -release -opensource -confirm-license -reduce-exports -ssl
 -qt-xcb -feature-accessibility -opengl desktop  -static -nomake examples
 -nomake tests -skip qtwebengine -skip qtscript -skip qt3d -skip qtandroidextras
 -skip qtwebview -skip qtwebsockets -skip qtdoc -skip qtcharts
 -skip qtdatavis3d -skip qtgamepad -skip qtmultimedia -skip qtsensors
 -skip qtserialbus -skip qtserialport -skip qtwebchannel -skip qtwayland \
  -prefix /opt/usr

# Build Qt, this is long
RUN cd qt-e* && make -j8
RUN cd qt-e* && make install

# Not very clean, but running tests in this environment hits a lot of
# bugs due to the unexpected static linkage.
RUN rm /opt/usr/lib/cmake/Qt5Test/Qt5TestConfig.cmake

# Set some variable before bootstrapping KF5
export Qt5_DIR=/opt/usr/
export CMAKE_PREFIX_PATH=/opt/usr/
export QT_INSTALL_PREFIX=/opt/usr/

RUN mkdir -p /bootstrap/build

ADD CMakeLists.txt /bootstrap/CMakeRingWrapper.txt.in
ADD CMakeRingWrapper.txt.in /bootstrap/CMakeRingWrapper.txt.in
ADD CMakeWrapper.txt.in /bootstrap/CMakeWrapper.txt.in
ADD patches /bootstrap/patches

RUN cd /bootstrap/build && cmake .. -CMAKE_INSTALL_PREFIX=/opt/ring-kde.AppDir
