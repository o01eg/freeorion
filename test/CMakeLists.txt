if (BUILD_PARSERS)
    add_subdirectory(parse)
endif ()
add_subdirectory(util)
add_subdirectory(system)

if (BUILD_CLIENT_GG)
    add_subdirectory(UI)
endif ()
