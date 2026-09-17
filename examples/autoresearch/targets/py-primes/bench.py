"""Fixed evaluation harness: do not edit. Prints `score: <median seconds>`."""
import statistics
import sys
import time

from solve import count_primes

LIMIT, EXPECTED, RUNS = 20000, 2262, 3

times = []
for _ in range(RUNS):
    started = time.perf_counter()
    answer = count_primes(LIMIT)
    times.append(time.perf_counter() - started)
    if answer != EXPECTED:
        sys.exit(f"wrong answer: {answer}, expected {EXPECTED}")
print(f"score: {statistics.median(times):.6f}")
