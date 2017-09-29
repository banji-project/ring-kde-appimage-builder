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
 -L/opt/usr/lib -L/opt/usr/plugins/platforms -lqminimal -lqxcb \
 -L/opt/usr/plugins/xcbglintegrations -lqxcb-egl-integration\
 -lqxcb-glx-integration -lQt5XcbQpa -lQt5LinuxAccessibilitySupport\
 -lQt5AccessibilitySupport -lQt5GlxSupport -lxcb-static -lxcb-glx\
 -L/opt/usr/plugins/imageformats -lqgif -lqicns -lqico -lqjpeg\
 -lqtga -lqtiff -lqwbmp -lqwebp\
 -L/opt/usr/plugins/egldeviceintegrations -lqeglfs-x11-integration\
 -lQt5EglFSDeviceIntegration -lQt5EventDispatcherSupport\
 -lQt5ServiceSupport -lQt5ThemeSupport -lQt5DBus -lQt5FontDatabaseSupport\
 -lQt5FbSupport -lQt5EglSupport -lXext -lQt5PlatformCompositorSupport\
 -lQt5InputSupport -lQt5Gui -lqtharfbuzz -lQt5DeviceDiscoverySupport\
 -lxcb -lX11 -lX11-xcb -lqtfreetype -lqtlibpng -lQt5Core -lm -ldl\
 -lrt -lqtpcre -lEGL -lGL -lpthread"
)

add_library(qt5pluginenabler STATIC ${CMAKE_CURRENT_BINARY_DIR}/pluginenabler.cpp)

target_link_libraries(qt5pluginenabler Qt5::Core)
