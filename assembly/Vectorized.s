code:
#define STDOUT 0xd0580000

.section .text

.global _start

_start:

## START YOUR CODE HERE

 la t0, real # Load base of input real array
 la t1, imag # Load base of input imag array
 la t2, bitrev_indices # Load bit-reversal lookup table
 la t3, rev_real # Destination for reordered real values
 la t4, rev_imag # Destination for reordered imag values
 li t5, 0 # i = 0

bitrev_loop:
 li t6, 128
 bge t5, t6, end_bitrev
 
 slli s4, t5, 2 # i * 4
 add s5, t2, s4 # bitrev + 4*i
 lw s6, 0(s5) # bitrev[i] → s6, Get bit-reversed index
 
 slli s7, s6, 2 # rev_index * 4
 add s8, t0, s4 # addr = real + i * 4
 add s9, t1, s4 # addr = imag + i * 4
 
 flw ft0, 0(s8) # Load real[i]
 flw ft1, 0(s9) # Load imag[i]
 
 add s8, t3, s7 # addr = rev_real + rev_index * 4
 add s9, t4, s7 # addr = rev_imag + rev_index * 4
 
 fsw ft0, 0(s8) # store to rev_real[bitrev[i]]
 fsw ft1, 0(s9) # store to rev_imag[bitrev[i]]
 
 addi t5, t5, 1 # Increment loop index.
 j bitrev_loop # Jump back to start of loop.

end_bitrev:

# ----------------------------- FFT SETUP -----------------------------

 li t5, 128 # total number of input elements (128 point fft)
 li t6, 7 # Since log₂(128) = 7, there are 7 stages in a radix-2 FFT for 128 inputs.

# Load base addresses of your reordered inputs
 la s0, rev_real # base address of rev_real[]
 la s1, rev_imag # base address of rev_imag[]

# Load base addresses of twiddle factors
 la s2, twiddle_real
 la s3, twiddle_imag

 li s4, 1 # s4 = 1, current FFT stage number

# ----------------------------- FFT COMPUTATION -----------------------------

outer_stage_loop:
 li t6, 7
 bgt s4, t6, end_fft_stages # If stage > log2(N), we're done

 li s5, 1
 sll s5, s5, s4 # s5 = m = 2^s (group size for this stage)
 
 srli s6, s5, 1 # s6 = half_m = m/2 (used for butterfly pairing)
 
 li s7, 128 # s7 = N = number of input points
 div s8, s7, s5 # s8 = twiddle_stride = N / m

 li t0, 0 # t0 = i = 0 (Reset the 'i' index for this stage)

outer_i_loop:
 bge t0, s7, end_outer_i_loop # if i >= N, exit this stage

 li s9, 0 # Initialize butterfly pair index j = 0

inner_butterfly_loop:
  bge s9, s6, end_inner_butterfly # if j >= m/2

  # Compute twiddle factor index
  mul s10, s9, s8
  slli s11, s10, 2

  # Load twiddle factors
  add t1, s2, s11     # &twiddle_real[j * stride]
  flw ft0, 0(t1)      # ft0 = wr

  add t1, s3, s11     # &twiddle_imag[j * stride]
  flw ft1, 0(t1)      # ft1 = wi

  # Compute top and bottom index offsets
  add t1, t0, s9       # t1 = i + j
  slli t2, t1, 2       # byte offset
  add t3, t1, s6       # t3 = i + j + m/2
  slli t4, t3, 2       # byte offset

  # Set VL for one element
  li t6, 1
  vsetvli t6, t6, e32, m1

  # Load a_real = rev_real[i + j]
  add t5, s0, t2
  vle32.v v0, (t5)

  # Load a_imag = rev_imag[i + j]
  add t5, s1, t2
  vle32.v v1, (t5)

  # Load b_real = rev_real[i + j + m/2]
  add t5, s0, t4
  vle32.v v2, (t5)

  # Load b_imag = rev_imag[i + j + m/2]
  add t5, s1, t4
  vle32.v v3, (t5)

  # Broadcast twiddle_real and twiddle_imag
  vfmv.v.f v4, ft0  # v4 = wr
  vfmv.v.f v5, ft1  # v5 = wi

  # Complex multiply: (wr*b_real - wi*b_imag)
  vfmul.vv v6, v2, v4     # b_real * wr
  vfmul.vv v7, v3, v5     # b_imag * wi
  vfsub.vv v8, v6, v7     # twiddle_real_part = v8

  vfmul.vv v6, v3, v4     # b_imag * wr
  vfmul.vv v7, v2, v5     # b_real * wi
  vfadd.vv v9, v6, v7     # twiddle_imag_part = v9

  # Compute top: a + twiddle*b
  vfadd.vv v10, v0, v8    # new_a_real
  vfadd.vv v11, v1, v9    # new_a_imag

  # Compute bottom: a - twiddle*b
  vfsub.vv v12, v0, v8    # new_b_real
  vfsub.vv v13, v1, v9    # new_b_imag

  # Store new_a_real
  add t5, s0, t2
  vse32.v v10, (t5)

  # Store new_a_imag
  add t5, s1, t2
  vse32.v v11, (t5)

  # Store new_b_real
  add t5, s0, t4
  vse32.v v12, (t5)

  # Store new_b_imag
  add t5, s1, t4
  vse32.v v13, (t5)

  # Increment j++
  addi s9, s9, 1
  j inner_butterfly_loop

end_inner_butterfly:
 add t0, t0, s5        # i += m
 j outer_i_loop

end_outer_i_loop:
 addi s4, s4, 1        # Next stage
 j outer_stage_loop

end_fft_stages:

# ----------------------------- WRITE FINAL FFT OUTPUT -----------------------------

# Save final real part (rev_real) to "output_real.hex"
la a0, filename_real    # a0 = address of filename string
mv a1, s0              # a1 = pointer to rev_real buffer
li a2, 128 * 4         # a2 = byte count (128 floats)
call write_to_file

# Save final imag part (rev_imag) to "output_imag.hex"
la a0, filename_imag    # a0 = address of filename string
mv a1, s1              # a1 = pointer to rev_imag buffer
li a2, 128 * 4
call write_to_file

 j _finish

# ----------------------------- For output -----------------------------

# Inputs: a0 = filename address, a1 = buffer address, a2 = length
# Return: Result of the 'close' call (0 on success, -1 on error)
# Clobbers: t0-t6, a0-a7 (standard caller-saved)
# Uses: s0 (for file descriptor), s1 (for buffer address), s2 (for length)
# Saves: ra, s0, s1, s2 on stack
write_to_file:
 addi sp, sp, -16       # Allocate stack space
 sw ra, 0(sp)           # Save return address
 sw s0, 4(sp)           # Save s0 (will store file descriptor)
 sw s1, 8(sp)           # Save s1 (will save original buffer address)
 sw s2, 12(sp)          # Save s2 (will save original length)

# --- Save original inputs a1 (buffer address) and a2 (length) ---
 mv s1, a1              # Save original buffer address in s1
 mv s2, a2              # Save original length in s2

# --- Open the file ---
# Arguments for open:
# a0 = filename address (input arg 1 - already correct)
# a1 = flags (O_WRONLY | O_CREAT | O_TRUNC = 0x601)
# a2 = mode (0666 = 0x1b6)
# a0 is already the filename address
 li a1, 0x601           # Load flags directly into a1
 li a2, 0x1b6           # Load mode (0666) directly into a2
 call open              # Call the open function

# File descriptor is now in a0. Save it.
 mv s0, a0              # Save the file descriptor in s0

# --- Write to the file ---
# Arguments for write:
# a0 = file descriptor (from s0)
# a1 = buffer address (from s1)
# a2 = count (from s2)
 mv a0, s0              # Move the file descriptor from s0 to a0
 mv a1, s1              # Restore buffer address from s1 to a1
 mv a2, s2              # Restore length from s2 to a2
 call write             # Call the write function

# --- Close the file ---
# Arguments for close:
# a0 = file descriptor (from s0)
 mv a0, s0              # Move the file descriptor from s0 to a0
 call close             # Call the close function

# --- Function Epilogue ---
# Restore saved registers
 lw ra, 0(sp)           # Restore return address
 lw s0, 4(sp)           # Restore s0
 lw s1, 8(sp)           # Restore s1
 lw s2, 12(sp)          # Restore s2
 addi sp, sp, 16        # Deallocate stack space
 ret                    # Return from the function (a0 contains close result)

# ----------------------------- Stop Function -----------------------------

_finish:
 li x3, 0xd0580000
 addi x5, x0, 0xff
 sb x5, 0(x3)
 beq x0, x0, _finish
 .rept 100
 nop
 .endr


.section .data
.align 4

# This array defines the real parts of the 128 input samples, your input is a sine wave sin(2pin/16)
real:
.float 0.00000000, 0.38268343, 0.70710678, 0.92387953, 1.00000000, 0.92387953, 0.70710678, 0.38268343
.float 0.00000000, -0.38268343, -0.70710678, -0.92387953, -1.00000000, -0.92387953, -0.70710678, -0.38268343
.float -0.00000000, 0.38268343, 0.70710678, 0.92387953, 1.00000000, 0.92387953, 0.70710678, 0.38268343
.float 0.00000000, -0.38268343, -0.70710678, -0.92387953, -1.00000000, -0.92387953, -0.70710678, -0.38268343
.float -0.00000000, 0.38268343, 0.70710678, 0.92387953, 1.00000000, 0.92387953, 0.70710678, 0.38268343
.float 0.00000000, -0.38268343, -0.70710678, -0.92387953, -1.00000000, -0.92387953, -0.70710678, -0.38268343
.float -0.00000000, 0.38268343, 0.70710678, 0.92387953, 1.00000000, 0.92387953, 0.70710678, 0.38268343
.float 0.00000000, -0.38268343, -0.70710678, -0.92387953, -1.00000000, -0.92387953, -0.70710678, -0.38268343
.float -0.00000000, 0.38268343, 0.70710678, 0.92387953, 1.00000000, 0.92387953, 0.70710678, 0.38268343
.float 0.00000000, -0.38268343, -0.70710678, -0.92387953, -1.00000000, -0.92387953, -0.70710678, -0.38268343
.float -0.00000000, 0.38268343, 0.70710678, 0.92387953, 1.00000000, 0.92387953, 0.70710678, 0.38268343
.float 0.00000000, -0.38268343, -0.70710678, -0.92387953, -1.00000000, -0.92387953, -0.70710678, -0.38268343
.float -0.00000000, 0.38268343, 0.70710678, 0.92387953, 1.00000000, 0.92387953, 0.70710678, 0.38268343
.float 0.00000000, -0.38268343, -0.70710678, -0.92387953, -1.00000000, -0.92387953, -0.70710678, -0.38268343
.float -0.00000000, 0.38268343, 0.70710678, 0.92387953, 1.00000000, 0.92387953, 0.70710678, 0.38268343
.float 0.00000000, -0.38268343, -0.70710678, -0.92387953, -1.00000000, -0.92387953, -0.70710678, -0.38268343

imag:
.rept 128
    .float 0.0 #all initialized to 0 meaning our entire input is real like a sine or cosine wave
.endr

#These arrays store the intermediate reordered data after bit-reversal, before FFT begins.
rev_real: .space 512     #means reserve 512 bytes, Since each float is 4 bytes, this space holds: 512 / 4 = 128 floats
rev_imag: .space 512

#Bit-Reversal Lookup Table
bitrev_indices:
.word 0, 64, 32, 96, 16, 80, 48, 112, 8, 72, 40, 104, 24, 88, 56, 120, 4, 68, 36, 100, 20, 84, 52, 116, 12, 76, 44, 108, 28, 92, 60, 124, 2, 66, 34, 98, 18, 82, 50, 114, 10, 74, 42, 106, 26, 90, 58, 122, 6, 70, 38, 102, 22, 86, 54, 118, 14, 78, 46, 110, 30, 94, 62, 126, 1, 65, 33, 97, 17, 81, 49, 113, 9, 73, 41, 105, 25, 89, 57, 121, 5, 69, 37, 101, 21, 85, 53, 117, 13, 77, 45, 109, 29, 93, 61, 125, 3, 67, 35, 99, 19, 83, 51, 115, 11, 75, 43, 107, 27, 91, 59, 123, 7, 71, 39, 103, 23, 87, 55, 119, 15, 79, 47, 111, 31, 95, 63, 127

#precomputed twiddle factors used in butterfly calculations
twiddle_real:
.float 1.00000000, 0.99879546, 0.99518473, 0.98917651, 0.98078528, 0.97003125, 0.95694034, 0.94154407, 0.92387953, 0.90398929, 0.88192126, 0.85772861, 0.83146961, 0.80320753, 0.77301045, 0.74095113, 0.70710678, 0.67155895, 0.63439328, 0.59569930, 0.55557023, 0.51410274, 0.47139674, 0.42755509, 0.38268343, 0.33688985, 0.29028468, 0.24298018, 0.19509032, 0.14673047, 0.09801714, 0.04906767, 0.00000000, -0.04906767, -0.09801714, -0.14673047, -0.19509032, -0.24298018, -0.29028468, -0.33688985, -0.38268343, -0.42755509, -0.47139674, -0.51410274, -0.55557023, -0.59569930, -0.63439328, -0.67155895, -0.70710678, -0.74095113, -0.77301045, -0.80320753, -0.83146961, -0.85772861, -0.88192126, -0.90398929, -0.92387953, -0.94154407, -0.95694034, -0.97003125, -0.98078528, -0.98917651, -0.99518473, -0.99879546

#This is the imaginary part of each input sample.
twiddle_imag:
.float -0.00000000, -0.04906767, -0.09801714, -0.14673047, -0.19509032, -0.24298018, -0.29028468, -0.33688985, -0.38268343, -0.42755509, -0.47139674, -0.51410274, -0.55557023, -0.59569930, -0.63439328, -0.67155895, -0.70710678, -0.74095113, -0.77301045, -0.80320753, -0.83146961, -0.85772861, -0.88192126, -0.90398929, -0.92387953, -0.94154407, -0.95694034, -0.97003125, -0.98078528, -0.98917651, -0.99518473, -0.99879546, -1.00000000, -0.99879546, -0.99518473, -0.98917651, -0.98078528, -0.97003125, -0.95694034, -0.94154407, -0.92387953, -0.90398929, -0.88192126, -0.85772861, -0.83146961, -0.80320753, -0.77301045, -0.74095113, -0.70710678, -0.67155895, -0.63439328, -0.59569930, -0.55557023, -0.51410274, -0.47139674, -0.42755509, -0.38268343, -0.33688985, -0.29028468, -0.24298018, -0.19509032, -0.14673047, -0.09801714, -0.04906767

size: .word 128

filename_real: .string "output_real.hex"
filename_imag: .string "output_imag.hex"