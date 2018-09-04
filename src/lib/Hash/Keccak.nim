#Import the Keccak Tiny lib.
import keccak_tiny

#Keccak 256 hashing algorithm.
proc Keccak_256*(input: string): string {.raises: [].} =
    $keccak_tiny.keccak_256(input)

#Keccak 512 hashing algorithm.
proc Keccak_512*(input: string): string {.raises: [].} =
    $keccak_tiny.keccak_512(input)
