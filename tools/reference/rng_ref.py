"""Эталон xoshiro128** + seeding, идентичный addons/master_core/rng/seeded_rng.gd."""
import json, sys
M = 0xFFFFFFFF
def rotl(x, k): return ((x << k) | (x >> (32 - k))) & M
def fnv1a32(s):
    h = 0x811C9DC5
    for b in s.encode('utf-8'): h = ((h ^ b) * 0x01000193) & M
    return h
class Rng:
    def __init__(self, seed):
        z = (seed ^ (seed >> 32)) & M; st = []
        for _ in range(4):
            z = (z + 0x9E3779B9) & M; t = z
            t = ((t ^ (t >> 16)) * 0x85EBCA6B) & M
            t = ((t ^ (t >> 13)) * 0xC2B2AE35) & M
            t ^= t >> 16; st.append(t & M)
        self.s = st
        if st == [0, 0, 0, 0]: self.s[0] = 1
    def next(self):
        s0, s1, s2, s3 = self.s
        r = (rotl((s1 * 5) & M, 7) * 9) & M
        t = (s1 << 9) & M
        s2 ^= s0; s3 ^= s1; s1 ^= s2; s0 ^= s3; s2 ^= t; s3 = rotl(s3, 11)
        self.s = [s0, s1, s2, s3]; return r
    def randi_range(self, lo, hi):
        n = hi - lo + 1; limit = 0x100000000 - (0x100000000 % n)
        while True:
            x = self.next()
            if x < limit: return lo + x % n
if __name__ == '__main__':
    out = {}
    for seed in [1, 20261125, 0x7FFFFFFFFFFF]:
        r = Rng(seed); out[str(seed)] = [r.next() for _ in range(1000)]
    r = Rng(fnv1a32("заказ 2026-11-25")); out["str"] = [r.next() for _ in range(1000)]
    r = Rng(42); out["range_0_6"] = [r.randi_range(0, 6) for _ in range(1000)]
    out["fnv"] = {"": fnv1a32(""), "a": fnv1a32("a"), "Давление": fnv1a32("Давление")}
    json.dump(out, open(sys.argv[1], 'w'))
