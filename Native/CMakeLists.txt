cmake_minimum_required(VERSION 3.22)
project(TajsGraphBMNative LANGUAGES CXX)

# By default this subproject expects the top-level TajsGraphBM CMakeLists
# to add RE-UE4SS first and provide the 'UE4SS' target.
#
# Optional standalone mode:
#   cmake -S Native -B Native/build -DTAJSGRAPHBM_STANDALONE=ON -DUE4SS_SRC_DIR=".../RE-UE4SS"
option(TAJSGRAPHBM_STANDALONE "Configure Native module directly (adds RE-UE4SS in this project)" OFF)
if(TAJSGRAPHBM_STANDALONE)
    if(NOT DEFINED UE4SS_SRC_DIR)
        message(FATAL_ERROR "UE4SS_SRC_DIR is required in standalone mode")
    endif()
    if(NOT EXISTS "${UE4SS_SRC_DIR}/CMakeLists.txt")
        message(FATAL_ERROR "UE4SS_SRC_DIR does not point to a valid RE-UE4SS source tree")
    endif()
    add_subdirectory("${UE4SS_SRC_DIR}" "${CMAKE_BINARY_DIR}/RE-UE4SS")
endif()

if(NOT TARGET UE4SS)
    message(FATAL_ERROR "Target 'UE4SS' not found. Configure from mod root or enable TAJSGRAPHBM_STANDALONE.")
endif()

set(TARGET TajsGraphBMNative)

add_library(${TARGET} SHARED
    src/console_bridge.cpp
    src/tajsgraph_mod.cpp
    src/umg_bridge.cpp
    src/mod_entry.cpp
)

target_compile_features(${TARGET} PRIVATE cxx_std_20)
target_include_directories(${TARGET} PRIVATE src)
target_link_libraries(${TARGET} PUBLIC UE4SS)

set_target_properties(${TARGET} PROPERTIES
    OUTPUT_NAME "main"
)

set(MOD_DEPLOY_DIR "${CMAKE_CURRENT_LIST_DIR}/../dlls")
add_custom_command(TARGET ${TARGET} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${MOD_DEPLOY_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:${TARGET}>" "${MOD_DEPLOY_DIR}/main.dll"
    COMMENT "Deploying main.dll to ${MOD_DEPLOY_DIR}"
)
