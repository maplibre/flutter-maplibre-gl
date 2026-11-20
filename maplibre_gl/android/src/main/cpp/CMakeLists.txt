cmake_minimum_required(VERSION 3.22.1)
project(maplibregl_mesh_layer CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(maplibregl_mesh_layer SHARED mesh_layer.cpp)
target_compile_options(maplibregl_mesh_layer PRIVATE -O2 -fvisibility=hidden -Wall)
target_link_libraries(maplibregl_mesh_layer GLESv3 EGL log)
