find_package(benchmark REQUIRED)

add_executable(fo_benchmark_util
)

target_include_directories(fo_benchmark_util
    PRIVATE
        ${PROJECT_SOURCE_DIR}
)

target_link_libraries(fo_benchmark_util
    Threads::Threads
    Boost::boost
    Boost::disable_autolinking
    Boost::dynamic_linking
    benchmark::benchmark
    benchmark::benchmark_main
)

target_dependencies_copy_to_build(fo_benchmark_util)

add_dependencies(benchmark
    fo_benchmark_util
)

set(FO_BENCHMARK_UTIL
    CheckSumsBench
)

foreach(_TEST ${FO_BENCHMARK_UTIL})
    target_sources(fo_benchmark_util
        PRIVATE
        ${_TEST}.cpp
    )
    add_test(
        NAME ${_TEST}
        COMMAND fo_benchmark_util "--benchmark_filter=${_TEST}"
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
endforeach()

