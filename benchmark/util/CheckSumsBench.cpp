#include <benchmark/benchmark.h>

#include "util/CheckSums.h"

static void CheckSumsBench(benchmark::State& state) {
    uint32_t sum = 0;
    for (auto _ : state)
        CheckSums::CheckSumCombine(sum, static_cast<uint32_t>(10));
}

BENCHMARK(CheckSumsBench);



