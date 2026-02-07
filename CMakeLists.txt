cmake_minimum_required(VERSION 3.17)

# Assuming user runs cmake from a build sub folder
set(CMAKE_INSTALL_PREFIX ..)

# -------------- video encoding library --------------
project(encode DESCRIPTION "library for encoding video files from lua using ffi")

find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBAV REQUIRED IMPORTED_TARGET
    libavformat
    libavcodec
    libswresample
    libswscale
    libavutil
)

add_library(encode SHARED
	src/game_handler/video/encode.c
)
target_link_libraries(encode
    PkgConfig::LIBAV
)

install(TARGETS encode RUNTIME DESTINATION lib)
