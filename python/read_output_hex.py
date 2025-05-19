import struct

def read_floats(filename):
    with open(filename, "rb") as f:
        data = f.read()
        return [struct.unpack('<f', data[i:i+4])[0] for i in range(0, len(data), 4)]

# Read real and imaginary parts
real_vals = read_floats("output_real.hex")
imag_vals = read_floats("output_imag.hex")

# Display complex FFT output
print("Complex FFT Output (real + imag·j):\n")
for i, (re, im) in enumerate(zip(real_vals, imag_vals)):
    sign = '+' if im >= 0 else '-'
    print(f"Bin {i:3}: {re:.6f} {sign} {abs(im):.6f}j")