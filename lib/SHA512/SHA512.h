#ifndef SHA512_H
#define SHA512_H

#include <memory.h>

#include <stdint.h>
#include <stdlib.h>

#include <string.h>
#include <stdio.h>

typedef struct {
    uint64_t length;
    uint64_t state[8];
    uint32_t curlen;
    uint8_t buf[128];
} SHA512Context;

#define MIN(x, y) ((x < y) ? x : y)
#define Ch(x, y, z)  (z ^ (x & (y ^ z)))
#define Maj(x, y, z) (((x | y) & z) | (x & y))
#define R(x, n) (((x)&0xFFFFFFFFFFFFFFFFULL)>>((uint64_t)n))
#define Sigma0(x) (ROR64(x, 28) ^ ROR64(x, 34) ^ ROR64(x, 39))
#define Sigma1(x) (ROR64(x, 14) ^ ROR64(x, 18) ^ ROR64(x, 41))
#define Gamma0(x) (ROR64(x, 1) ^ ROR64(x, 8) ^ R(x, 7))
#define Gamma1(x) (ROR64(x, 19) ^ ROR64(x, 61) ^ R(x, 6))
#define ROR64(value, bits) (((value) >> (bits)) | ((value) << (64 - (bits))))

#define SHA512Round(a, b, c, d, e, f, g, h, i)      \
    t0 = h + Sigma1(e) + Ch(e, f, g) + K[i] + W[i]; \
    t1 = Sigma0(a) + Maj(a, b, c);                  \
    d += t0;                                        \
    h  = t0 + t1;

#define LOAD64H(x, y) {                                                             \
    x = (((uint64_t) ((y)[0] & 255)) << 56) | (((uint64_t) ((y)[1] & 255)) << 48) | \
        (((uint64_t) ((y)[2] & 255)) << 40) | (((uint64_t) ((y)[3] & 255)) << 32) | \
        (((uint64_t) ((y)[4] & 255)) << 24) | (((uint64_t) ((y)[5] & 255)) << 16) | \
        (((uint64_t) ((y)[6] & 255)) << 8)  | (((uint64_t) ((y)[7] & 255)));        \
}

void STORE64H(uint64_t x, uint8_t* y) {
    y[0] = (uint8_t) ((x >> 56) & 255);
    y[1] = (uint8_t) ((x >> 48) & 255);
    y[2] = (uint8_t) ((x >> 40) & 255);
    y[3] = (uint8_t) ((x >> 32) & 255);
    y[4] = (uint8_t) ((x >> 24) & 255);
    y[5] = (uint8_t) ((x >> 16) & 255);
    y[6] = (uint8_t) ((x >> 8) & 255);
    y[7] = (uint8_t) (x & 255);
}

int BLOCK_SIZE = 128;
static const uint64_t K[80] = {
    0x428a2f98d728ae22ULL, 0x7137449123ef65cdULL, 0xb5c0fbcfec4d3b2fULL, 0xe9b5dba58189dbbcULL,
    0x3956c25bf348b538ULL, 0x59f111f1b605d019ULL, 0x923f82a4af194f9bULL, 0xab1c5ed5da6d8118ULL,
    0xd807aa98a3030242ULL, 0x12835b0145706fbeULL, 0x243185be4ee4b28cULL, 0x550c7dc3d5ffb4e2ULL,
    0x72be5d74f27b896fULL, 0x80deb1fe3b1696b1ULL, 0x9bdc06a725c71235ULL, 0xc19bf174cf692694ULL,
    0xe49b69c19ef14ad2ULL, 0xefbe4786384f25e3ULL, 0x0fc19dc68b8cd5b5ULL, 0x240ca1cc77ac9c65ULL,
    0x2de92c6f592b0275ULL, 0x4a7484aa6ea6e483ULL, 0x5cb0a9dcbd41fbd4ULL, 0x76f988da831153b5ULL,
    0x983e5152ee66dfabULL, 0xa831c66d2db43210ULL, 0xb00327c898fb213fULL, 0xbf597fc7beef0ee4ULL,
    0xc6e00bf33da88fc2ULL, 0xd5a79147930aa725ULL, 0x06ca6351e003826fULL, 0x142929670a0e6e70ULL,
    0x27b70a8546d22ffcULL, 0x2e1b21385c26c926ULL, 0x4d2c6dfc5ac42aedULL, 0x53380d139d95b3dfULL,
    0x650a73548baf63deULL, 0x766a0abb3c77b2a8ULL, 0x81c2c92e47edaee6ULL, 0x92722c851482353bULL,
    0xa2bfe8a14cf10364ULL, 0xa81a664bbc423001ULL, 0xc24b8b70d0f89791ULL, 0xc76c51a30654be30ULL,
    0xd192e819d6ef5218ULL, 0xd69906245565a910ULL, 0xf40e35855771202aULL, 0x106aa07032bbd1b8ULL,
    0x19a4c116b8d2d0c8ULL, 0x1e376c085141ab53ULL, 0x2748774cdf8eeb99ULL, 0x34b0bcb5e19b48a8ULL,
    0x391c0cb3c5c95a63ULL, 0x4ed8aa4ae3418acbULL, 0x5b9cca4f7763e373ULL, 0x682e6ff3d6b2b8a3ULL,
    0x748f82ee5defb2fcULL, 0x78a5636f43172f60ULL, 0x84c87814a1f0ab72ULL, 0x8cc702081a6439ecULL,
    0x90befffa23631e28ULL, 0xa4506cebde82bde9ULL, 0xbef9a3f7b2c67915ULL, 0xc67178f2e372532bULL,
    0xca273eceea26619cULL, 0xd186b8c721c0c207ULL, 0xeada7dd6cde0eb1eULL, 0xf57d4f7fee6ed178ULL,
    0x06f067aa72176fbaULL, 0x0a637dc5a2c898a6ULL, 0x113f9804bef90daeULL, 0x1b710b35131c471bULL,
    0x28db77f523047d84ULL, 0x32caab7b40c72493ULL, 0x3c9ebe0a15c9bebcULL, 0x431d67c49c100d4cULL,
    0x4cc5d4becb3e42b6ULL, 0x597f299cfc657e2aULL, 0x5fcb6fab3ad6faecULL, 0x6c44198c4a475817ULL
};

static void TransformFunction(SHA512Context* Context, uint8_t const* Buffer) {
    uint64_t S[8];
    uint64_t W[80];
    uint64_t t0;
    uint64_t t1;
    int i;

    for (i = 0; i < 8; i++) {
        S[i] = Context->state[i];
    }

    for (i = 0; i < 16; i++) {
        LOAD64H(W[i], Buffer + (8*i));
    }

    for (i = 16; i < 80; i++) {
        W[i] = Gamma1(W[i-2]) + W[i-7] + Gamma0(W[i-15]) + W[i-16];
    }

    for (i = 0; i < 80; i += 8) {
        SHA512Round(S[0], S[1], S[2], S[3], S[4], S[5], S[6], S[7], i+0);
        SHA512Round(S[7], S[0], S[1], S[2], S[3], S[4], S[5], S[6], i+1);
        SHA512Round(S[6], S[7], S[0], S[1], S[2], S[3], S[4], S[5], i+2);
        SHA512Round(S[5], S[6], S[7], S[0], S[1], S[2], S[3], S[4], i+3);
        SHA512Round(S[4], S[5], S[6], S[7], S[0], S[1], S[2], S[3], i+4);
        SHA512Round(S[3], S[4], S[5], S[6], S[7], S[0], S[1], S[2], i+5);
        SHA512Round(S[2], S[3], S[4], S[5], S[6], S[7], S[0], S[1], i+6);
        SHA512Round(S[1], S[2], S[3], S[4], S[5], S[6], S[7], S[0], i+7);
    }

    for (i = 0; i < 8; i++) {
        Context->state[i] = Context->state[i] + S[i];
    }
}

void SHA512Initialize(SHA512Context* Context) {
    Context->curlen = 0;
    Context->length = 0;
    Context->state[0] = 0x6a09e667f3bcc908ULL;
    Context->state[1] = 0xbb67ae8584caa73bULL;
    Context->state[2] = 0x3c6ef372fe94f82bULL;
    Context->state[3] = 0xa54ff53a5f1d36f1ULL;
    Context->state[4] = 0x510e527fade682d1ULL;
    Context->state[5] = 0x9b05688c2b3e6c1fULL;
    Context->state[6] = 0x1f83d9abfb41bd6bULL;
    Context->state[7] = 0x5be0cd19137e2179ULL;
}

void SHA512Update(SHA512Context* Context, void const* Buffer, uint32_t BufferSize) {
    uint32_t n;

    if (Context->curlen > sizeof(Context->buf)) {
        return;
    }

    while (BufferSize > 0) {
        if ((Context->curlen) == 0 && (BufferSize >= BLOCK_SIZE)) {
            TransformFunction(Context, (uint8_t *) Buffer);
            Context->length += BLOCK_SIZE * 8;
            Buffer = (uint8_t*)Buffer + BLOCK_SIZE;
            BufferSize -= BLOCK_SIZE;
        } else {
            n = MIN( BufferSize, (BLOCK_SIZE - Context->curlen) );
            memcpy( Context->buf + Context->curlen, Buffer, (size_t)n );
            Context->curlen += n;
            Buffer = (uint8_t*)Buffer + n;
            BufferSize -= n;
            if (Context->curlen == BLOCK_SIZE) {
                TransformFunction( Context, Context->buf );
                Context->length += 8*BLOCK_SIZE;
                Context->curlen = 0;
            }
        }
    }
}

void SHA512Finalize(SHA512Context* Context, uint8_t* Digest) {
    int i;

    if (Context->curlen >= sizeof(Context->buf)) {
        return;
    }

    Context->length += (Context->curlen * 8ULL);

    Context->buf[Context->curlen++] = (uint8_t) 0x80;

    if (Context->curlen > 112) {
        while (Context->curlen < 128) {
            Context->buf[Context->curlen++] = (uint8_t) 0;
        }
        TransformFunction( Context, Context->buf );
        Context->curlen = 0;
    }

    while (Context->curlen < 120) {
        Context->buf[Context->curlen++] = (uint8_t) 0;
    }

    STORE64H(Context->length, Context->buf+120);
    TransformFunction(Context, Context->buf);

    for (i = 0; i < 8; i++) {
        STORE64H( Context->state[i], Digest+(8*i) );
    }
}

char toReturn[129];
char* sha512(char* hexString) {
    int hexDigits = strlen(hexString)/2;

    uint8_t hexData[hexDigits];
    char temp[2];
    for (int i = 0; i < hexDigits; i++) {
        temp[0] = hexString[i*2];
        temp[1] = hexString[(i*2)+1];
        hexData[i] = (uint8_t) strtol(temp, NULL, 16);
    }

    SHA512Context localContext;
    SHA512Initialize(&localContext);

    SHA512Update(&localContext, hexData, (uint32_t) hexDigits);

    uint8_t localHash[64];
    SHA512Finalize(&localContext, localHash);

    for (int i = 0; i < sizeof(localHash); i++) {
        sprintf(temp, "%2.2x", (int) localHash[i]);
        toReturn[i*2] = temp[0];
        toReturn[(i*2)+1] = temp[1];
    }
    toReturn[128] = 0;
    return toReturn;
}

#endif
