#ifndef LYRA2_WRAPPER_H
#define LYRA2_WRAPPER_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Lyra2.h"

char ret[64];
int resLen = 32;
char* calcLyra2(char* data, char* salt) {
    unsigned char* res = malloc(resLen);
    cLYRA2(res, resLen, (unsigned char*) data, strlen(data), (unsigned char*) salt, strlen(salt), 1, 100000, 256);

    for (int i = 0; i < resLen; i++) {
        sprintf(ret + (2*i), "%02x", res[i]);
    }

    free(res);
    return ret;
}

#endif
