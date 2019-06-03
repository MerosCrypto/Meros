#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Ed25519 lib.
import Ed25519
#Export the objects.
export EdSeed, EdPublicKey, EdSignature

#Address lib.
import Address
#Export the Address lib.
export Address

#Finals lib.
import finals

finalsd:
    #Wallet object.
    type Wallet* = object of RootObj
        #Initiated.
        initiated*: bool
        #Private Key.
        privateKey*: EdPrivateKey
        #Public Key.
        publicKey*: EdPublicKey
        #Address.
        address*: string

#Create a new Public Key from a string.
func newEdPublicKey*(
    key: string
): EdPublicKey {.forceCheck: [
    EdPublicKeyError
].} =
    #If it's binary...
    if key.len == 32:
        for i in 0 ..< 32:
            result.data[i] = key[i]
    #If it's hex...
    elif key.len == 64:
        try:
            for i in countup(0, 63, 2):
                result.data[i div 2] = cuchar(parseHexInt(key[i .. i + 1]))
        except ValueError:
            raise newException(EdPublicKeyError, "Hex-length Public Key with invalid Hex data passed to newEdSeed.")
    else:
        raise newException(EdPublicKeyError, "Invalid length Public Key passed to newEdPublicKey.")

#Create a new Signature from a string.
func newEdSignature*(
    sigArg: string
): EdSignature {.forceCheck: [
    ValueError
].} =
    var sig: string
    if sigArg.len == 64:
        sig = sigArg
    elif sigArg.len == 128:
        try:
            sig = sigArg.parseHexStr()
        except ValueError:
            raise newException(ValueError, "Hex-length Signature with invalid Hex data passed to newEdSignature.")
    else:
        raise newException(ValueError, "Invalid length Signature passed to new EdSignature.")

    copyMem(addr result.data[0], addr sig[0], 64)

#Sign a message via a Wallet.
func sign*(
    wallet: Wallet,
    msg: string
): EdSignature {.forceCheck: [
    SodiumError
].} =
    try:
        result = wallet.privateKey.sign(msg)
    except SodiumError as e:
        fcRaise e

#Verify a signature.
func verify*(
    key: EdPublicKey,
    msg: string,
    sig: EdSignature
): bool {.forceCheck: [].} =
    try:
        result = Ed25519.verify(key, msg, sig)
    except SodiumError:
        return false

#Verify a signature via a Wallet.
func verify*(
    wallet: Wallet,
    msg: string,
    sig: EdSignature
): bool {.forceCheck: [].} =
    try:
        result = wallet.publicKey.verify(msg, sig)
    except SodiumError:
        return false

#Stringify a Seed/PublicKey/Signature.
func toString*(
    data: EdSeed or EdPrivateKey or EdPublicKey or EdSignature
): string {.forceCheck: [].} =
    for b in data.data:
        result = result & char(b)

func `$`*(
    data: EdSeed or EdPrivateKey or EdPublicKey or EdSignature
): string {.inline, forceCheck: [].} =
    data.toString().toHex()
