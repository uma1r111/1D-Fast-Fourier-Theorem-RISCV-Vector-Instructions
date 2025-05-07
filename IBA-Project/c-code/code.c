#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define PI 3.14159265358979323846f
#define MAX 128  // Maximum signal length

int logint(int N) {
    int k = N, i = 0;
    while (k) {
        k >>= 1;
        i++;
    }
    return i - 1;
}

int reverse(int N, int n) {
    int j, p = 0;
    for (j = 1; j <= logint(N); j++) {
        if (n & (1 << (logint(N) - j)))
            p |= 1 << (j - 1);
    }
    return p;
}

void ordina(float *real, float *imag, int N) {
    float real_temp[MAX], imag_temp[MAX];
    for (int i = 0; i < N; i++) {
        int rev_index = reverse(N, i);
        real_temp[i] = real[rev_index];
        imag_temp[i] = imag[rev_index];
    }
    for (int j = 0; j < N; j++) {
        real[j] = real_temp[j];
        imag[j] = imag_temp[j];
    }
}

float *sin_cos_approx(float a) {
    static float result[2];

    const float half_pi_hi = 1.57079637e+0f;
    const float half_pi_lo = -4.37113883e-8f;

    float c, j, rc, rs, s, sa, t;
    int i, ic;

    j = fmaf(a, 6.36619747e-1f, 12582912.f) - 12582912.f; // 2/pi * a
    a = fmaf(j, -half_pi_hi, a);
    a = fmaf(j, -half_pi_lo, a);

    i = (int)j;
    ic = i + 1;

    sa = a * a;

    c = 2.44677067e-5f;
    c = fmaf(c, sa, -1.38877297e-3f);
    c = fmaf(c, sa, 4.16666567e-2f);
    c = fmaf(c, sa, -5.00000000e-1f);
    c = fmaf(c, sa, 1.00000000e+0f);

    s = 2.86567956e-6f;
    s = fmaf(s, sa, -1.98559923e-4f);
    s = fmaf(s, sa, 8.33338592e-3f);
    s = fmaf(s, sa, -1.66666672e-1f);
    t = a * sa;
    s = fmaf(s, t, a);

    rs = (i & 1) ? c : s;
    rc = (i & 1) ? s : c;

    rs = (i & 2) ? -rs : rs;
    rc = (ic & 2) ? -rc : rc;

    result[0] = rs;
    result[1] = rc;

    return result;
}

void transform(float *real, float *imag, int N) {
    ordina(real, imag, N);

    float *W_real = (float *)malloc(N / 2 * sizeof(float));
    float *W_imag = (float *)malloc(N / 2 * sizeof(float));

    for (int i = 0; i < N / 2; i++) {
        float angle = -2.0 * PI * i / N;
        float *sincos = sin_cos_approx(angle);
        W_real[i] = sincos[1];  // cos(angle)
        W_imag[i] = sincos[0];  // sin(angle)
    }

    int n = 1;
    int a = N / 2;

    for (int stage = 0; stage < logint(N); stage++) {
        for (int i = 0; i < N; i++) {
            if (!(i & n)) {
                float temp_real = real[i];
                float temp_imag = imag[i];

                int k = (i * a) % (n * a);
                float W_real_k = W_real[k];
                float W_imag_k = W_imag[k];

                float t_real = W_real_k * real[i + n] - W_imag_k * imag[i + n];
                float t_imag = W_real_k * imag[i + n] + W_imag_k * real[i + n];

                real[i]      = temp_real + t_real;
                imag[i]      = temp_imag + t_imag;
                real[i + n]  = temp_real - t_real;
                imag[i + n]  = temp_imag - t_imag;
            }
        }
        n *= 2;
        a = a / 2;
    }

    free(W_real);
    free(W_imag);
}

void FFT(float *real, float *imag, int N, float d) {
    transform(real, imag, N);
    for (int i = 0; i < N; i++) {
        real[i] *= d;
        imag[i] *= d;
    }
}

int main() {
    int n = 128;      // FFT size
    float d = 1.0f;   // Step size (no scaling)

    float real[MAX], imag[MAX] = {0};

    // Sample input: sine wave at 8 Hz
    for (int i = 0; i < n; i++) {
        real[i] = sin(2 * PI * 8 * i / n);
    }

    FFT(real, imag, n, d);

    printf("FFT Result (first 16 frequencies):\n");
    for (int i = 0; i < 16; i++) {
        printf("X[%d] = %f + %fi\n", i, real[i], imag[i]);
    }

    return 0;
}