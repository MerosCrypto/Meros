#Import the Keccak Tiny lib.
import keccak_tiny

#SHA3 256 hashing algorithm.
proc SHA3_256*(input: string): string {.raises: [].} =
    $keccak_tiny.sha3_256(input)

#SHA3 512 hashing algorithm.
proc SHA3_512*(input: string): string {.raises: [].} =
    $keccak_tiny.sha3_512(input)

#Have SHA3 be the default SHA functions.
var
    SHA256*: proc (input: string): string {.raises: [].} = SHA3_256
    SHA512*: proc (input: string): string {.raises: [].} = SHA3_512
