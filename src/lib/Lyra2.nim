#Wrapper for the Lyra2 C library made by the people behind Lyra2

#C function
proc cCalcLyra2(data: cstring, salt: cstring): cstring {.header: "../../src/lib/Lyra2/wrapper.h", importc: "calcLyra2".}
#Take in data and a salt, return a 64 character string
proc Lyra2*(data: string, salt: string): string =
    result = $cCalcLyra2((cstring) data, (cstring) salt)
