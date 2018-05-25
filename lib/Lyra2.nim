proc cCalcLyra2(data: cstring, salt: cstring): cstring {.header: "../lib/Lyra2/wrapper.h", importc: "calcLyra2".}
proc Lyra2*(data: string, salt: string): string =
    result = $cCalcLyra2((cstring) data, (cstring) salt)
