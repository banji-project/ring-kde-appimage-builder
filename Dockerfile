FROM elv13/old_gentoo

# Bypass tools that attempt to "optimize" flags
ENV CXX="g++ -static-libgcc -static-libstdc++"

ENV LDFLAGS="-static-libstdc++ -fuse-linker-plugin -Wl,--gc-sections -Wl,--strip-all -Wl,--as-needed"
ENV CXXFLAGS="-Os -ffunction-sections -fdata-sections -Wl,--gc-sections -Wl,--strip-all"
ENV CFLAGS="-Os -ffunction-sections -fdata-sections -Wl,--gc-sections -Wl,--strip-all"
#ENV LDFLAGS="-static-libstdc++ -flto -O -fuse-linker-plugin -Wl,--gc-sections"
#ENV CXXFLAGS="-ffunction-sections -fdata-sections -flto -Wl,--gc-sections"
#ENV CFLAGS="-ffunction-sections -fdata-sections -flto -Wl,--gc-sections"

RUN emerge --sync
RUN eselect python set 1

ADD make.conf /etc/portage/

#RUN echo '>=sys-libs/glibc-2.18' >> /etc/portage/package.mask/package.mask

#ENV FEATURES="-sandbox -usersandbox"
#ENV USE="static static-libs"

# It's part of the profile, not muc to do
RUN echo net-misc/openssh -static >> /etc/portage/package.use

RUN cat /etc/portage/make.conf

RUN echo '<=sys-devel/gcc-8' >> /etc/portage/package.unmask
RUN echo '<=sys-devel/gcc-8 **' >> /etc/portage/package.keywords

RUN emerge gcc
RUN binutils-config --linker ld.gold
RUN gcc-config `gcc-config -l | wc -l`

#RUN emerge -e @world --update || echo Failed, but keep going

# Select the new GCC and rebuild
RUN gcc-config `gcc-config -l | wc -l`
RUN emerge -e @world || echo 'Failed, but keep going (self host)'

# Enable loop optimization and rebuild
#ENV USE="graphite lto"
#RUN emerge -e @world || echo 'Failed, but keep going (self host, poly)'
#RUN echo  'CFLAGS="$CFLAGS -fgraphite-identity -fgraphite -floop-interchange -ftree-loop-distribution -floop-strip-mine -floop-block"' >> /etc/portage/make.conf
#RUN echo  'CXXFLAGS="$CFLAGS"' >> /etc/portage/make.conf

# Enable LTO and rebuild
#RUN echo 'CFLAGS="$CFLAGS -flto=8"' >> /etc/portage/make.conf
#RUN echo 'CXXFLAGS="$CFLAGS"' >> /etc/portage/make.conf
#RUN echo 'LDFLAGS="-flto=8 $LDFLAGS"' >> /etc/portage/make.conf
#RUN emerge -e @world || echo 'Failed, but keep going (self host, LTO)'

RUN cat /etc/portage/make.conf

# Download Qt in order to build a minimal library
RUN wget http://qt.mirrors.tds.net/qt/archive/qt/5.8/5.8.0/single/qt-everywhere-opensource-src-5.8.0.tar.gz &&\
 tar -zxvf qt-everywhere-opensource-src-5.8.0.tar.gz

# Qt5 needs the Gl API
RUN emerge mesa freeglut dev-python/common

# Replace the default performance Qt flags for portability ones
RUN sed 's/-O3/-Os/' -i /qt-everywhere-opensource-src-5.8.0/qtbase/mkspecs/common/qcc-base.conf
RUN sed 's/-O2/-Os/' -i /qt-everywhere-opensource-src-5.8.0/qtbase/mkspecs/common/qcc-base.conf
RUN sed 's/-O3/-Os/' -i /qt-everywhere-opensource-src-5.8.0/qtbase/mkspecs/common/gcc-base.conf
RUN sed 's/-O2/-Os/' -i /qt-everywhere-opensource-src-5.8.0/qtbase/mkspecs/common/gcc-base.conf
RUN echo 'QMAKE_CXXFLAGS -=-O3' >> /qt-everywhere-opensource-src-5.8.0/qtbase/mkspecs/linux-g++/qmake.conf
RUN echo 'QMAKE_CXXFLAGS_RELEASE -=-O3' >> /qt-everywhere-opensource-src-5.8.0/qtbase/mkspecs/linux-g++/qmake.conf
RUN echo 'QMAKE_CXXFLAGS -=-O2' >> /qt-everywhere-opensource-src-5.8.0/qtbase/mkspecs/linux-g++/qmake.conf
RUN echo 'QMAKE_CXXFLAGS_RELEASE -=-O2' >> /qt-everywhere-opensource-src-5.8.0/qtbase/mkspecs/linux-g++/qmake.conf
RUN echo 'QMAKE_CXXFLAGS=-Os' >> /qt-everywhere-opensource-src-5.8.0/qtbase/mkspecs/linux-g++/qmake.conf
RUN echo 'QMAKE_CXXFLAGS_RELEASE=-Os' >> /qt-everywhere-opensource-src-5.8.0/qtbase/mkspecs/linux-g++/qmake.conf
RUN find /qt-everywhere-opensource-src-5.8.0/ | xargs grep O3 2> /dev/null \
 | grep -v xml | grep -v Binary 2> /dev/null | cut -f1 -d ':' \
 | grep -E '\.(conf|mk|sh|am|in)$' | xargs sed -i 's/O3/Os/'

# Build a static Qt package with as little system dependencies as
# possible
RUN cd qt-e* &&\
  ./configure -v -release -opensource -confirm-license -reduce-exports -ssl \
   -qt-xcb -feature-accessibility -opengl desktop  -static -nomake examples \
   -nomake tests -skip qtwebengine -skip qtscript -skip qt3d -skip qtandroidextras \
   -skip qtwebview -skip qtwebsockets -skip qtdoc -skip qtcharts \
   -skip qtdatavis3d -skip qtgamepad -skip qtmultimedia -skip qtsensors \
   -skip qtserialbus -skip qtserialport -skip qtwebchannel -skip qtwayland \
   -prefix /opt/usr -no-glib -qt-zlib -qt-freetype -ltcg

# Build Qt, this is long
RUN cd qt-e* && make -j8
RUN cd qt-e* && make install
RUN rm -rf qt-e # Keep the docker image smaller

# Not very clean, but running tests in this environment hits a lot of
# bugs due to the unexpected static linkage.
RUN rm /opt/usr/lib/cmake/Qt5Test/Qt5TestConfig.cmake

# Set some variable before bootstrapping KF5
ENV Qt5_DIR=/opt/usr/
ENV CMAKE_PREFIX_PATH=/opt/usr/
RUN QT_INSTALL_PREFIX=/opt/usr/

# Begin building KF5
#RUN apt install gperf gettext libxcb-keysyms1-dev libxrender-dev \
# libxcb-image0-dev libxcb-xinerama0-dev flex bison -y
RUN USE="-gpg -pcre -perl -python -threads -webdav" emerge gperf gettext \
 flex bison x11-libs/xcb-util-keysyms dev-vcs/git yasm \
 media-libs/alsa-lib

RUN git clone https://anongit.kde.org/extra-cmake-modules
RUN cd extra-cmake-modules && mkdir build && cd build && cmake .. \
 -DCMAKE_INSTALL_PREFIX=/ && make -j8 install

RUN mkdir -p /bootstrap/build

RUN mkdir /opt/ring-kde.AppDir -p

# This is necessary to build Ring with Pulse and video accel
# **WARNING** This has to be executed AFTER Qt has been installed to
# avoid poluting the system with versions of those packages
#RUN apt install libvdpau-dev libva-dev gettext autopoint libasound-dev \
# libpulse-dev libudev-dev wget libdbus-1-dev -y



# Fetch the ring library (without the daemon)
RUN git clone https://github.com/savoirfairelinux/ring-daemon --progress --verbose

# A new dependency was introduced on October 2 2017, I don't care about it
RUN cd ring-daemon && git checkout c3648232db3bb679be2d967688d311a221c5cf5c

# Add the patch now as the daemon use them
ADD patches /bootstrap/patches

RUN cd ring-daemon && git apply /bootstrap/patches/ring-daemon.patch
RUN mkdir -p ring-daemon/contrib/native && cd ring-daemon/contrib/native &&\
 CXXFLAGS=" -ffunction-sections -fdata-sections  -Wno-error=unused-result -Wno-unused-result -Os" CFLAGS=" -ffunction-sections -fdata-sections  -Wno-error=unused-result -Wno-unused-result -Os" ../bootstrap --disable-dbus-cpp --enable-vorbis --enable-ogg \
   --enable-opus --enable-zlib --enable-uuid --enable-uuid && make fetch-all -j8

RUN emerge yasm
#RUN CFLAGS="" LDFLAGS="" emerge sys-fs/fuse

# TODO remove
#ENV LDFLAGS="-flto=8 $LDFLAGS"
#ENV CFLAGS="-flto=8 $CFLAGS"
#ENV CXXFLAGS="$CFLAGS"

# Cross compile hack
RUN cd ring-daemon/contrib/native && CXXFLAGS="-Wno-error=unused-result -Wno-unused-result -Os -ffunction-sections -fdata-sections " CFLAGS="-Os -Wno-error=unused-result -Wno-unused-result -ffunction-sections -fdata-sections " make -j8 || echo ignore2 #HACK
RUN cp /usr/share/libtool/build-aux/config.guess /ring-daemon/contrib/native/uuid/
RUN cp /usr/share/libtool/build-aux/config.sub /ring-daemon/contrib/native/uuid/

#HACK!!!!!
RUN cd ring-daemon/contrib/native &&\
 ../bootstrap --disable-dbus-cpp --enable-vorbis --enable-ogg \
   --enable-opus --enable-zlib --enable-uuid --enable-uuid && make fetch-all

# Build all the static dependencies
RUN cd ring-daemon/contrib/native && make -j8

# Compile the daemon. Pulse is disabled for now because it pulls
# too many dependencies are cause libring to link to them...
RUN cd ring-daemon &&  ./autogen.sh && CXXFLAGS="-ffunction-sections -fdata-sections -Os" ./configure --without-dbus \
 --enable-static --without-pulse --disable-vdpau --disable-vaapi \
 --disable-videotoolbox --disable-vda --disable-accel --disable-shared \
 --prefix=/opt/ring-kde.AppDir && make -j install && echo bar

# Only add the file after the Daemon is built to speedup image creation
ADD CMakeLists.txt /bootstrap/CMakeLists.txt
ADD CMakeRingWrapper.txt.in /bootstrap/CMakeRingWrapper.txt.in
ADD CMakeWrapper.txt.in /bootstrap/CMakeWrapper.txt.in
ADD cmake /bootstrap/cmake

# Build all the frameworks and prepare Ring-KDE
RUN cd /bootstrap/build && CXXFLAGS="" LDFLAGS="" cmake .. -DCMAKE_INSTALL_PREFIX=/opt/ring-kde.AppDir\
 -DCMAKE_BUILD_TYPE=Release -DDISABLE_KDBUS_SERVICE=1 \
 -DRING_BUILD_DIR=/ring-daemon/src/ -Wno-dev || echo Ignore3

# Add the appimages
RUN wget "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
RUN chmod a+x appimagetool-x86_64.AppImage

# Add the icons and desktop
RUN cp /bootstrap/build/ring-kde/ring-kde/data/*.desktop /opt/ring*/
RUN cp /bootstrap/build/ring-kde/ring-kde/data/icons/sc-apps-ring-kde.svgz \
  /opt/ring-kde.AppDir/ring-kde.svgz

ADD AppRun /opt/ring-kde.AppDir/

RUN sed -i 's/DBusActivatable=true/X-DBusActivatable=true/' -i /opt/ring-kde.AppDir/*.desktop

ADD AppRun /opt/ring-kde.AppDir/

# FIXME
RUN cp /lib/libpcre.so.1 /opt/ring-kde.AppDir/lib/
RUN cp /usr/lib/libasound.so.2 /opt/ring-kde.AppDir/lib/

# TODO: Fix this too
RUN echo '#include <QtPlugin>' > /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QXcbIntegrationPlugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QtQuick2Plugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QtQuickControls2Plugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QtQuick2WindowPlugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QEvdevKeyboardPlugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QEvdevMousePlugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QtQuickLayoutsPlugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QtQuickTemplates2Plugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QtQuickControls1Plugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QJpegPlugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QSvgPlugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QSvgIconPlugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QXcbGlxIntegrationPlugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QtGraphicalEffectsPlugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QtGraphicalEffectsPrivatePlugin)' >> /bootstrap/build/newmain.cpp
RUN echo 'Q_IMPORT_PLUGIN(QtQmlModelsPlugin)' >> /bootstrap/build/newmain.cpp

RUN ls /bootstrap/build/

RUN cat /bootstrap/build/ring-kde/ring-kde/src/main.cpp >> /bootstrap/build/newmain.cpp
RUN cp /bootstrap/build/newmain.cpp /bootstrap/build/ring-kde/ring-kde/src/main.cpp
RUN cd /bootstrap/build/ring-kde/ring-kde/ && git apply /bootstrap/patches/ring-kde.patch


# Make sure there is fallback fonts and color Emojis
ADD fonts /fonts
RUN mkdir /opt/ring-kde.AppDir/fonts
ADD fonts/* /opt/ring-kde.AppDir/fonts/

# TODO: Fix it (Gentoo call it differently)
#RUN cp /lib/x86_64-linux-gnu/libpcre.so.3 /opt/ring-kde.AppDir/lib/

# Fuse doesn't link with gold
RUN LDFLAGS="$LDFLAGS -Wl,-fuse-ld=bfd" emerge sys-fs/fuse

CMD cd /bootstrap/build && make -j8 install && find /opt/ring-kde.AppDir/ \
  | grep -v ring-kde | xargs rm -rf &&\
   rm -rf /opt/ring-kde.AppDir/share/locale/ && /appimagetool-x86_64.AppImage\
  /opt/ring-kde.AppDir/ /export/ring-kde.appimage
