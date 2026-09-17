"""The file under research. Keep `count_primes(limit)` correct; make it fast."""


def is_prime(n):
    if n < 2:
        return False
    for d in range(2, n):
        if n % d == 0:
            return False
    return True


def count_primes(limit):
    return sum(1 for n in range(limit) if is_prime(n))
