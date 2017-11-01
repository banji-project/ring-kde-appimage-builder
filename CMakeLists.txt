CMAKE_MINIMUM_REQUIRED(VERSION 3.5)

PROJECT(Ring-KDE.app)

SET(QT_MIN_VERSION  "5.7.0")
set(CMAKE_BUILD_TYPE RELEASE)

ADD_DEFINITIONS(-DQT_STATIC)

SET(LOCAL_CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/")

#QTBUG-38913
# All static linking elements have to be added "by force" as the package
# provides an incomplete list.
set(CMAKE_CXX_CREATE_SHARED_LIBRARY "${CMAKE_CXX_CREATE_SHARED_LIBRARY} \
 /opt/usr/lib/libqtfreetype.a /opt/usr/lib/libqtharfbuzz.a /opt/usr/lib/libqtlibpng.a /opt/usr/lib/libqtpcre.a -ldl -lpthread"
)

set(CMAKE_CXX_LINK_EXECUTABLE "${CMAKE_CXX_LINK_EXECUTABLE} \
 /opt/usr/lib/libqtfreetype.a /opt/usr/lib/libqtharfbuzz.a /opt/usr/lib/libqtlibpng.a /opt/usr/lib/libqtpcre.a -ldl -lpthread"
)

# Make sure KF5 subdirectory see each others

set(BUILD_WITH_QTSCRIPT OFF)
option(BUILD_WITH_QTSCRIPT OFF)

FIND_PACKAGE(Qt5 ${QT_MIN_VERSION} CONFIG REQUIRED
  Core
  Widgets
  Gui
  Svg
  QuickControls2
  Quick
)

set(ALL_KF5_DIR "set(ECM_DIR \"${CMAKE_CURRENT_BINARY_DIR}/extra-cmake-modules/install/share/ECM/cmake/\")")
set(ALL_KF5_LIST "")


# HACK
execute_process(COMMAND
    bash -c 'gcc -v 2>&1 | grep Target | cut -f2 -d" "'
    RESULT_VARIABLE NATIVE_TARGET_NAME
)

if (EXISTS "/usr/lib/${NATIVE_TARGET_NAME}")
    set(LIBDIR_NAME "lib/${NATIVE_TARGET_NAME}")
else()
    set(LIBDIR_NAME "lib64")
endif()

function(fetch_framework name frmname) #opt: EXTRA_LD BRANCH
    list(APPEND ALL_KF5_LIST "${CMAKE_CURRENT_BINARY_DIR}/${name}/install/")
    set(ALL_KF5_LIST ${ALL_KF5_LIST} PARENT_SCOPE)

    if (EXISTS "${CMAKE_CURRENT_BINARY_DIR}/${name}/done")
        set(FRM_DIR "${CMAKE_CURRENT_BINARY_DIR}/${name}/install/${LIBDIR_NAME}/cmake/${frmname}/")
        set(${frmname}_DIR "${FRM_DIR}" PARENT_SCOPE)
        set(ALL_KF5_DIR "${ALL_KF5_DIR}\nset(${frmname}_DIR \"${FRM_DIR}\")" PARENT_SCOPE)

        return()
    endif()

    # Extra aurguments are assumed to be LD_FLAGS
    set(EXTRA_LD "${ARGV2}")

    # Wrap each framework in an additional CMakeLists.txt to add static
    # Qt support
    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${name})
    set(SUB_DIR_NAME ${name})
    configure_file(${CMAKE_SOURCE_DIR}/CMakeWrapper.txt.in ${CMAKE_CURRENT_BINARY_DIR}/${name}/CMakeLists.txt @ONLY)

    if (NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/${name}/${name})
        if (NOT "${ARGV3}" STREQUAL "")
            set(BRANCH "${ARGV3}")
        else()
            set(BRANCH v5.38.0)
        endif()

        execute_process(COMMAND
             git clone https://anongit.kde.org/${name} --branch ${BRANCH} ${CMAKE_CURRENT_BINARY_DIR}/${name}/${name}/
             RESULT_VARIABLE CLONE_RES
        )

        if (NOT ${CLONE_RES} MATCHES 0)
            message(FATAL_ERROR "Could not clone ${name}")
        endif()
    else()
#        execute_process(COMMAND
#            /bin/sh -c "cd ${CMAKE_CURRENT_BINARY_DIR}/${name}/${name} && git fetch origin && git reset --hard origin/master"
#        )
    endif()

    # Apply the patches until they are merged
    if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/patches/${name}.patch)
        execute_process(COMMAND
            git apply ${CMAKE_CURRENT_SOURCE_DIR}/patches/${name}.patch
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${name}/${name}
        )
    endif()

    # This would be nice, but for now seems out of reach
    #add_subdirectory(${CMAKE_CURRENT_BINARY_DIR}/${name})
    #set(${frmname}_DIR "${CMAKE_CURRENT_BINARY_DIR}/build/${name}" PARENT_SCOPE)

    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${name}/build/)

    execute_process(COMMAND
        cmake ../ -DCMAKE_INSTALL_PREFIX=${CMAKE_CURRENT_BINARY_DIR}/${name}/install -Wno-dev -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${name}/build/
        RESULT_VARIABLE CMAKE_CMD_RES
    )

    execute_process(COMMAND
        make VERBOSE=1 ENABLE_VERBOSE=1 -j8 install
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${name}/build/
        RESULT_VARIABLE MAKE_CMD_RES
    )

    if(${CMAKE_CMD_RES} MATCHES 0 AND ${MAKE_CMD_RES} MATCHES 0)
        set(FRM_DIR "${CMAKE_CURRENT_BINARY_DIR}/${name}/install/${LIBDIR_NAME}/cmake/${frmname}/")

        set(${frmname}_DIR "${FRM_DIR}" PARENT_SCOPE)
        set(ALL_KF5_DIR "${ALL_KF5_DIR}\nset(${frmname}_DIR \"${FRM_DIR}\")" PARENT_SCOPE)

        # Make sure not to do this everytime
        file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/${name}/done" "1")
    else()
        message(FATAL_ERROR "Failed to compile ${frmname} ${CMAKE_CMD_RES} ${MAKE_CMD_RES}")
        exit(1)
    endif()
endfunction()

#TODO install ECM normally
#fetch_framework(extra-cmake-modules "")

fetch_framework(kcoreaddons KF5CoreAddons)
fetch_framework(kconfig KF5Config)
fetch_framework(kauth KF5Auth)
fetch_framework(kcodecs KF5Codecs)
fetch_framework(kguiaddons KF5GuiAddons)
fetch_framework(kwidgetsaddons KF5WidgetsAddons)
fetch_framework(kdbusaddons KF5DBusAddons)
fetch_framework(ki18n KF5I18n)
fetch_framework(karchive KF5Archive)
fetch_framework(kitemviews KF5ItemViews)
fetch_framework(kwindowsystem KF5WindowSystem)
fetch_framework(kcompletion KF5Completion)
#fetch_framework(sonnet KF5Sonnet)
fetch_framework(kjobwidgets KF5JobWidgets)
fetch_framework(kpackage KF5Package)
#fetch_framework(kdoctools KF5DocTools)

#fetch_framework(phonon Phonon4Qt5)

fetch_framework(knotifications KF5Notifications)
fetch_framework(kcrash KF5Crash)
fetch_framework(kglobalaccel KF5GlobalAccel)
#fetch_framework(solid KF5Solid)
fetch_framework(kservice KF5Service)
fetch_framework(kconfigwidgets KF5ConfigWidgets)
fetch_framework(kiconthemes KF5IconThemes)
#fetch_framework(ktextwidgets KF5TextWidgets)
fetch_framework(kxmlgui KF5XmlGui)
#fetch_framework(kbookmarks KF5Bookmarks)
#fetch_framework(kio KF5KIO)

#fetch_framework(kinit KF5Init)
fetch_framework(knotifyconfig KF5NotifyConfig)
fetch_framework(kdeclarative KF5Declarative "-lGL -lGLU")
fetch_framework(kirigami KF5Kirigami2 "-lGL -lGLU")

# Style related stuff
#fetch_framework(qqc2-desktop-style QtQuickControls2DesktopStyle "" "master")

# Now, begin to setup Ring-KDE
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${ring-kde})

# FIXME: This is deadcode now that there is a `libtool` wrapper.
execute_process(COMMAND
    bash -c "for LIB in \$(find /ring-daemon/contrib/native/*/*/.libs/ | grep -E \"*\\.a\$\"); do echo -n \" \$LIB\";done"
    OUTPUT_VARIABLE DRING_STATIC
)

execute_process(COMMAND
    bash -c "for LIB in \$(find /ring-daemon/contrib/native/*/.libs/ | grep -E \"*\\.a\$\"); do echo -n \" \$LIB\";done"
    OUTPUT_VARIABLE DRING_STATIC2
)

execute_process(COMMAND
    bash -c "for LIB in \$(find /ring-daemon/contrib/native/*/lib*.a | grep -E \"*\\.a\$\"); do echo -n \" \$LIB\";done"
    OUTPUT_VARIABLE DRING_STATIC3
)

set(EXTRA_LD "${DRING_STATIC} ${DRING_STATIC2} ${DRING_STATIC3} -lGL -lGLU")

configure_file(${CMAKE_SOURCE_DIR}/CMakeRingWrapper.txt.in
    ${CMAKE_CURRENT_BINARY_DIR}/ring-kde/CMakeLists.txt
    @ONLY
)

set(BUILD_SHARED_LIBS OFF)
option(BUILD_SHARED_LIBS OFF)

#TODO convert to macro
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/qt5pluginenabler.cmake)

#execute_process(COMMAND
#    cmake ../ -DCMAKE_INSTALL_PREFIX=${CMAKE_CURRENT_BINARY_DIR}/${name}/install -Wno-dev
#    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/ring-kde/build/
#    RESULT_VARIABLE CMAKE_CMD_RES
#)

#add_subdirectory(${CMAKE_CURRENT_BINARY_DIR}/kstyle)

add_subdirectory(${CMAKE_CURRENT_BINARY_DIR}/ring-kde)

#foreach(DIR ${ALL_KF5_LIST})
#    message("BAR ${DIR}")
#    file(COPY ${DIR} DESTINATION ${CMAKE_INSTALL_PREFIX})
#endforeach()
