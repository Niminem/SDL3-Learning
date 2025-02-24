# https://github.com/libsdl-org/SDL_shadercross/

# This is a library for translating shaders to different formats, intended for use
# with SDL's GPU API.

# It takes SPIRV or HLSL as the source and outputs DXBC, DXIL, SPIRV, MSL, or HLSL.

# This library can perform runtime translation and conveniently returns compiled
# SDL GPU shader objects from HLSL or SPIRV source.

# This library also provides a command line interface for offline translation of shaders.

# For SPIRV translation, this library depends on SPIRV-Cross. spirv-cross-c-shared.dll
# (or your platform's equivalent) can be obtained in the Vulkan SDK. For compiling to DXIL,
# dxcompiler.dll and dxil.dll (or your platform's equivalent) are required.
# DXIL dependencies obtained here: https://github.com/microsoft/DirectXShaderCompiler/releases
# It is strongly recommended that you ship SPIRV-Cross and DXIL dependencies along with your
# application. For compiling to DXBC, d3dcompiler_47 is shipped with Windows.
# Other platforms require vkd3d-utils.

# https://vulkan.lunarg.com/
# 0.) Download Vulkan. We'll need this if we want to compile GLSL to SPIRV (glslc tool).
# - ex: glslc shader.glsl.frag -o shader.spv.frag
# - we can, in theory, then use shadercross to convert SPIRV to HLSL or MSL (pretty cool)

# https://github.com/libsdl-org/SDL
# 1.) need to build and install SDL3. Process:
# (currently for Nim bindings, it's built on /releases/tag/preview-3.1.8)
# git clone https://github.com/libsdl-org/SDL.git SDL3
# cd SDL3
# mkdir build
# cd build
# cmake .. -DCMAKE_INSTALL_PREFIX="C:/SDL3-installed" -DSDL_SHARED=ON -DSDL_STATIC=ON
# cmake --build . --config Release
# cmake --install .
# now add the following to your PATH environment variable:
# C:\SDL3-installed\bin

# https://github.com/microsoft/DirectXShaderCompiler
# get release (pre-built) and add to same parent folder as SDL3
# https://github.com/microsoft/DirectXShaderCompiler/releases

# https://github.com/KhronosGroup/SPIRV-Cross
# 2.) need to build and install SPIRV-Cross. Process:
# git clone https://github.com/KhronosGroup/SPIRV-Cross/tree/vulkan-sdk-{version}
# cd SPIRV-Cross
# mkdir build
# cd build
# cmake .. -DCMAKE_INSTALL_PREFIX="C:/spirv-cross-installed" -DSPIRV_CROSS_STATIC=ON -DSPIRV_CROSS_SHARED=ON -DSPIRV_CROSS_CLI=ON
# cmake --build . --config Release
# cmake --install .

# https://github.com/libsdl-org/SDL_shadercross/
# cmake .. `
#          -DCMAKE_INSTALL_PREFIX="C:/SDL_shadercross" `
#          -DSDLSHADERCROSS_SHARED=ON `
#          -DSDLSHADERCROSS_STATIC=ON `
#          -Dspirv_cross_c_shared_DIR="C:\spirv-cross-installed\share\spirv_cross_c_shared\cmake" `
#          -DSDL3_DIR="C:/SDL3-installed/cmake" `
#          -DDirectXShaderCompiler_INCLUDE_PATH="C:\DXC\inc" `
#          -DDirectXShaderCompiler_dxcompiler_LIBRARY="C:/DXC/lib/x64/dxcompiler.lib" `
#          -DDirectXShaderCompiler_dxil_BINARY="C:/DXC/bin/x64/dxil.dll" `
#          -DSDLSHADERCROSS_INSTALL=ON
# cmake --build . --config Release
# cmake --install .


# TODO:
    # - create nim wrapper
    # - create example app
    # - get it to work on my Mac machine as well (Linux users are on their own)
    # - create repository
    # - create readme (dump all the above here)