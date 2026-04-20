cmake_minimum_required(VERSION 3.22)
project(TajsGraphBMWorkspace LANGUAGES CXX)

# In-place layout (this repository):
#   ue4ss/Mods/TajsGraphBM        <- sourceDir (this CMakeLists)
#   ue4ss/RE-UE4SS                <- default UE4SS source sibling
#
# Build entry point:
#   cmake --preset vs2026-game
#   cmake --build --preset build-vs2026-game

set(TAJSGRAPHBM_DEFAULT_UE4SS_SRC "${CMAKE_CURRENT_LIST_DIR}/../../RE-UE4SS")
set(UE4SS_SRC_DIR "${TAJSGRAPHBM_DEFAULT_UE4SS_SRC}" CACHE PATH "Path to RE-UE4SS source checkout")

if(NOT EXISTS "${UE4SS_SRC_DIR}/CMakeLists.txt")
    message(FATAL_ERROR
        "UE4SS_SRC_DIR is invalid: '${UE4SS_SRC_DIR}'. "
        "Expected RE-UE4SS CMakeLists.txt. "
        "For this in-place layout, default is ../../RE-UE4SS from mod root."
    )
endif()

add_subdirectory("${UE4SS_SRC_DIR}" "${CMAKE_BINARY_DIR}/RE-UE4SS")
add_subdirectory(Native)
