# This CMake module allows to bundle what are usually plugins into the
# Qt5 application. Due to bugs in Qt5 official CMake integration, this
# relies on QMake to discover the proper linking flags. Trying to
# guess them by hand only results in cryptic linking errors or binary
# that simply doesn't work.

set(PLUGIN_CPP_HEADER "#include <QtPlugin>\n")


set(PLUGIN_CPP_HEADER "${PLUGIN_CPP_HEADER} Q_IMPORT_PLUGIN(QXcbIntegrationPlugin)")

# Create a simple static libraries with the expanded macros
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/pluginenabler.cpp ${PLUGIN_CPP_HEADER})

set(CMAKE_CXX_LINK_EXECUTABLE "${CMAKE_CXX_LINK_EXECUTABLE} \
/bootstrap/build/qqc2-desktop-style/install/lib64/qml/org.kde.desktop.private/libqqc2desktopstyleplugin.a /bootstrap/build/kirigami/install/lib64/qml/org/kde/kirigami.2/libkirigamiplugin.a /opt/usr/qml/QtQuick/Controls.2/libqtquickcontrols2plugin.a -L/opt/usr/lib /opt/usr/qml/QtQuick/Window.2/libwindowplugin.a /opt/usr/qml/QtQuick/Dialogs/libdialogplugin.a /opt/usr/qml/QtQuick/Layouts/libqquicklayoutsplugin.a -lQt5QuickControls2 /opt/usr/qml/QtQuick.2/libqtquick2plugin.a /opt/usr/qml/QtQuick/Templates.2/libqtquicktemplates2plugin.a -lQt5QuickTemplates2 /opt/usr/qml/QtGraphicalEffects/libqtgraphicaleffectsplugin.a /opt/usr/qml/QtGraphicalEffects/private/libqtgraphicaleffectsprivate.a /opt/usr/qml/QtQml/Models.2/libmodelsplugin.a -lQt5Quick -lQt5Qml -lQt5Network -L/opt/usr/plugins/imageformats -lqsvg -lQt5Svg /opt/usr/plugins/iconengines/libqsvgicon.a -lQt5Widgets -L/opt/usr/plugins/platforms -lqxcb -L/opt/usr/plugins/xcbglintegrations -lqxcb-egl-integration -lqxcb-glx-integration -lQt5XcbQpa -lQt5AccessibilitySupport -lQt5GlxSupport -lxcb-static -lxcb-glx -L/opt/usr/plugins/generic -lqevdevkeyboardplugin -lqevdevmouseplugin -lqgif -lqicns -lqico -lqjpeg -lqtga -lqtiff -lqwbmp -lqwebp -L/opt/usr/plugins/egldeviceintegrations -lqeglfs-x11-integration -lQt5EglFSDeviceIntegration -lQt5EventDispatcherSupport -lQt5ServiceSupport -lQt5ThemeSupport -lQt5DBus -lQt5FontDatabaseSupport -lQt5FbSupport -lQt5EglSupport -lXext -lQt5PlatformCompositorSupport -lQt5InputSupport -lQt5Gui -lqtharfbuzz -lQt5DeviceDiscoverySupport -lxcb -lX11 -lX11-xcb -lqtfreetype -lqtlibpng -lQt5Core -lm -ldl -lrt -lqtpcre2 -lEGL -lGL -lpthread\
")

add_library(qt5pluginenabler STATIC ${CMAKE_CURRENT_BINARY_DIR}/pluginenabler.cpp)

target_link_libraries(qt5pluginenabler Qt5::Core)
