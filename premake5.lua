workspace "Cloud-sim"
    location "build"
    configurations {"Release"}
    architecture "x64"
project "Cloud-sim"
    kind "ConsoleApp"
    language "C++"
    staticruntime "On"
    targetdir "build/bin/%{cfg.buildcfg}"
    files {"./src/*.cpp", "src/*.h"}
    includedirs {
        "include/"
    }
    libdirs {"lib"}
    links {"NWengineCore64.lib", "dwmapi"}
    optimize "On"
