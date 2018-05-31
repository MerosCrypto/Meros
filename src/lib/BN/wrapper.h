#include <stdio.h>
#include <stdlib.h>
#include "imath.h"

char* buf;
char* printMPZ_T(mpz_t* x) {
    int len = mp_int_string_len(x, 10);
    buf = calloc(len, sizeof(*buf));
    mp_int_to_string(x, 10, buf, len);
    return buf;
}
