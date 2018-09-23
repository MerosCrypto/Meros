#SECP256K1 Wrapper.
import ../lib/SECP256K1Wrapper

#Private Key lib.
import PrivateKey

#String utils standard lib.
import strutils

#Define the PublicKey class to be the secp256k1_pubkey object.
type PublicKey* = secp256k1_pubkey

#Create a new Public Key from a private key.
proc newPublicKey*(privKey: PrivateKey): PublicKey {.raises: [ValueError].} =
    result = secpPublicKey(privKey)

#Create a new Public Key from a hex string.
proc newPublicKey*(hex: string): PublicKey {.raises: [ValueError].} =
    result = secpPublicKey(hex)

#Verify a signature using a constructed Public Key.
proc verify*(key: PublicKey, hash: string, sig: string): bool {.raises: [ValueError].} =
    key.secpVerify("EMB" & hash, sig)

#Stringify a Public Key to it's compressed hex representation.
proc `$`*(key: PublicKey): string {.raises: [ValueError].} =
    #Use the secondary stringify function in the SSECP256K1 Wrapper.
    #$! is so we don't infinitely call this same function.
    result = $!key

#Convert a Public Key to a array[33, uint8].
proc toArray*(key: PublicKey): array[33, uint8] =
    SECP256K1Wrapper.toArray(key)
