cmake_minimum_required(VERSION 3.16)
project(analysis CXX)

find_package(ROOT REQUIRED)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(hello_root src/hello_root.cpp)
target_include_directories(hello_root PRIVATE ${ROOT_INCLUDE_DIRS})
target_link_libraries(hello_root PRIVATE ${ROOT_LIBRARIES})
