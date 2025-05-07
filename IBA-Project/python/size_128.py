import math

N = 128  # FFT size
log2_N = 7

def bit_reverse(i, bits):
    rev = 0
    for b in range(bits):
        if i & (1 << b):
            rev |= 1 << (bits - 1 - b)
    return rev

# ---- Bit reversal indices ----
print("\nbitrev_indices:")
print(".word", end=" ")
for i in range(N):
    rev = bit_reverse(i, log2_N)
    print(f"{rev}", end=", " if i != N - 1 else "\n")

# ---- Twiddle factors ----
print("\ntwiddle_real:")
print(".float", end=" ")
for k in range(N // 2):
    val = math.cos(2 * math.pi * k / N)
    print(f"{val:.8f}", end=", " if k != N//2 - 1 else "\n")

print("\ntwiddle_imag:")
print(".float", end=" ")
for k in range(N // 2):
    val = -math.sin(2 * math.pi * k / N)
    print(f"{val:.8f}", end=", " if k != N//2 - 1 else "\n")