#include <atomic>
#include <chrono>
#include <iostream>
#include <new> // Required for std::hardware_destructive_interference_size
#include <thread>

// 1. Structure susceptible to false sharing
struct MisalignedCounters {
  std::atomic<int> counter1 = {0};
  std::atomic<int> counter2 = {0};
  // These two counters might end up on the same cache line,
  // leading to performance degradation due to false sharing.
};

// 2. Structure aligned to avoid false sharing
struct AlignedCounters {
  alignas(std::hardware_destructive_interference_size)
      std::atomic<int> counter1 = {0};
  alignas(std::hardware_destructive_interference_size)
      std::atomic<int> counter2 = {0};
  // The alignas specifier ensures a minimum offset (the cache line size)
  // between counter1 and counter2, placing them on separate cache lines.
};

// Function to increment a counter in a loop
void increment_counter(std::atomic<int> &counter, int iterations) {
  for (int i = 0; i < iterations; ++i) {
    counter.fetch_add(1, std::memory_order_relaxed);
  }
}

// Benchmark function
template <typename T> void benchmark(const std::string &name) {
  T data;
  const int iterations = 10000000;
  auto start = std::chrono::high_resolution_clock::now();

  std::thread t1(increment_counter, std::ref(data.counter1), iterations);
  std::thread t2(increment_counter, std::ref(data.counter2), iterations);

  t1.join();
  t2.join();

  auto end = std::chrono::high_resolution_clock::now();
  std::chrono::duration<double, std::milli> elapsed = end - start;

  std::cout << name << " time: " << elapsed.count() << " ms\n";
  std::cout << "  (Cache line size on this system is approx. "
            << std::hardware_destructive_interference_size << " bytes)\n";
}

int main() {
  std::cout << "Benchmarking performance...\n";

  benchmark<MisalignedCounters>("MisalignedCounters (False Sharing likely)");
  benchmark<AlignedCounters>("AlignedCounters (False Sharing avoided)");

  return 0;
}
