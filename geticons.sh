#!/bin/bash

# Find icons in Qt code and package them
# Author: Emmanuel Lepage Vallee
# Copyright: Emmanuel Lepage Valle (2016)
# Licence: Mit

if [ "$1" == "" ] || [ "$2" == "" ]; then
   echo 'Usage: ./geticons.sh <repository> <theme_path>'
   exit 1
fi

REPO=$1
BUILD_DIR=$PWD

# Clear the previous data
rm -rf iconbundle
mkdir iconbundle/build -p

# Explain to CMake how to compile it
cat << EOF >> iconbundle/CMakeLists.txt
CMAKE_MINIMUM_REQUIRED(VERSION 3.5)

PROJECT(iconbundle)

IF(POLICY CMP0063)
   CMAKE_POLICY(SET CMP0063 NEW)
ENDIF(POLICY CMP0063)

SET(CMAKE_AUTOMOC ON)
SET(CMAKE_AUTORCC ON)
SET(CMAKE_AUTOUIC ON)

FIND_PACKAGE(Qt5 CONFIG REQUIRED
     Core
)

SET(GENERIC_LIB_VERSION "1.0.0")

QT5_ADD_RESOURCES(iconbundle_LIB_SRCS
    autobundledicons.qrc
)

ADD_LIBRARY( iconbundle  STATIC \${iconbundle_LIB_SRCS})

target_link_libraries( iconbundle \${iconbundle_LIB_SRCS})
EOF

# Create the index
cat << EOF >> iconbundle/index.theme
[Icon Theme]
Name=Breeze

Comment=Default Plasma 5 Theme for Dark themes
DisplayDepth=32

Inherits=hicolor

Example=folder

FollowsColorScheme=true

DesktopDefault=22
DesktopSizes=22
ToolbarDefault=22
ToolbarSizes=22
MainToolbarDefault=22
MainToolbarSizes=22
SmallDefault=22
SmallSizes=22
PanelDefault=22
PanelSizes=22
DialogDefault=22
DialogSizes=22

KDE-Extensions=.svg

Directories=actions/22,apps/22,devices/22,emblems/22,emotes/22,mimetypes/22,places/22,status/22,actions/symbolic,devices/symbolic,emblems/symbolic,places/symbolic,status/symbolic

[actions/22]
Size=22
Context=Actions
Type=Scalable

[apps/22]
Size=22
Context=Applications
Type=Scalable

[categories/32]
Size=32
Context=Categories
Type=Scalable

[devices/22]
Size=22
Context=Devices
Type=Scalable

[emblems/22]
Size=22
Context=Emblems
Type=Scalable

[emotes/22]
Size=22
Context=Emotes
Type=Scalable

[mimetypes/22]
Size=22
Context=MimeTypes
Type=Scalable

[places/22]
Size=22
Context=Places
Type=Fixed

[status/22]
Size=22
Context=Status
Type=Scalable
EOF

cd $REPO

# Find all icons from the code
ICONS=`git grep -i  fromTheme | grep -oE 'fromTheme[ (A-Za-z]*"[^"]+"' |
    grep -oE '"[^"]+"' | cut -f2 -d'"'`

LESSER2="<"

UI_ICONS=`git grep "${LESSER2}iconset theme=" | grep -oE '"[^"\[]+"' | cut -f2 -d'"'`

QML_ICONS=`git grep \"image://icon | grep -Eo 'icon/[^"]*' | cut -f2 -d '/'`

ICONS=$(echo -e $ICONS $UI_ICONS $QML_ICONS | sort | uniq)

cd $BUILD_DIR

echo '<RCC>' > iconbundle/autobundledicons.qrc
echo '  <qresource prefix="icons">' >> iconbundle/autobundledicons.qrc

# Copy all files
for NAME in $ICONS; do
    FILE=$(find /breeze-icons/breeze-icons/icons -iname "${NAME}.*"| grep 22)

    if [ ! -e "$FILE" ]; then
        FILE=$(find /breeze-icons/breeze-icons/icons -iname "${NAME}.*"| grep 16)
    fi

    if [ -e "$FILE" ]; then
        NEW_PATH=${BUILD_DIR}/iconbundle/$(echo $FILE | cut -f 7-99 -d'/')
        mkdir -p $(dirname $NEW_PATH)
        if [ ! -e $NEW_PATH ]; then
            ICON_PATH=${NAME}.svg
            echo "    <file alias='breeze/actions/22/$ICON_PATH' >$ICON_PATH</file>" >> iconbundle/autobundledicons.qrc
        fi
        cp $FILE $NEW_PATH
    fi
done

echo '    <file alias="breeze/index.theme" >index.theme</file>' >> iconbundle/autobundledicons.qrc
echo '  </qresource>' >> iconbundle/autobundledicons.qrc
echo '</RCC>' >> iconbundle/autobundledicons.qrc

# Compress everything
cd ${BUILD_DIR}/iconbundle
#gzip -S z *.svg

