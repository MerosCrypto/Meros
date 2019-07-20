#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Hash lib.
import ../lib/Hash

#Ed25519 lib.
import mc_ed25519

#SIGN_PREFIX applied to every message, stopping cross-network replays.
const SIGN_PREFIX {.strdefine.}: string = "MEROS"

#Export the Private/Public Key objects (with a prefix).
type
    EdPoint2* = Point2
    EdPoint3* = Point3
    EdPrivateKey* = object
        data*: PrivateKey
    EdPublicKey* = object
        data*: PublicKey
    EdSignature* = object
        data*: array[64, uint8]

#Constructors.
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
            raise newException(EdPublicKeyError, "Hex-length Public Key with invalid Hex data passed to newEdPublicKey.")
    else:
        raise newException(EdPublicKeyError, "Invalid length Public Key passed to newEdPublicKey.")

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

proc toPublicKey*(
    keyArg: EdPrivateKey
): EdPublicKey {.forceCheck: [].} =
    var
        #Extract the key argument.
        key: EdPrivateKey = keyArg
        #Public Key point.
        publicKeyPoint3: ptr EdPoint3 = cast[ptr EdPoint3](alloc0(sizeof(EdPoint3)))

    #Multiply the Public Key against the base.
    multiplyBase(publicKeyPoint3, addr key.data[0])
    serialize(addr result.data[0], publicKeyPoint3)

#Nim function for signing a message.
func sign*(
    privKeyArg: EdPrivateKey,
    pubKeyArg: EdPublicKey,
    msgArg: string
): EdSignature {.forceCheck: [].} =
    #Extract the arguments.
    var
        privKey: EdPrivateKey = privKeyArg
        pubKey: EdPublicKey = pubKeyArg
        msg: string = SIGN_PREFIX & msgArg

    #Create the signature.
    sign(
        cast[ptr cuchar](addr result.data[0]),
        cast[ptr cuchar](addr msg[0]),
        csize(msg.len),
        cast[ptr cuchar](addr pubKey.data[0]),
        cast[ptr cuchar](addr privKey.data[0])
    )

#Nim function for verifying a message.
func verify*(
    keyArg: EdPublicKey,
    msgArg: string,
    sigArg: EdSignature
): bool {.forceCheck: [].} =
    #Extract the argsuments.
    var
        key: EdPublicKey = keyArg
        msg: string = SIGN_PREFIX & msgArg
        sig: EdSignature = sigArg

    #Verify the signature.
    if verify(
        cast[ptr cuchar](addr sig.data[0]),
        cast[ptr cuchar](addr msg[0]),
        csize(msg.len),
        addr key.data[0]
    ) == 1:
        return true

    result = false

#Stringify.
func toString*(
    data: EdPrivateKey or EdPublicKey or EdSignature
): string {.forceCheck: [].} =
    for b in data.data:
        result = result & char(b)

func `$`*(
    data: EdPrivateKey or EdPublicKey or EdSignature
): string {.inline, forceCheck: [].} =
    data.toString().toHex()

#Aggregate Public Keys.
var blankScalar: array[32, cuchar]
proc aggregate*(
    keys: var seq[EdPublicKey]
): EdPublicKey {.forceCheck: [].} =
    if keys.len == 1:
        return keys[0]

    var
        bytes: string
        l: SHA2_256Hash
        keyHash: SHA2_256Hash
        keyPoint: EdPoint3
        a: EdPoint2
        tempRes: PointP1P1
        tempCached: PointCached
        res: EdPoint3

    for key in keys:
        bytes &= key.toString()
    l = SHA2_256(bytes)
    bytes = newString(64)

    for k in 0 ..< keys.len:
        keyHash = SHA2_256(l.toString() & keys[k].toString())
        copyMem(addr bytes[0], addr keyHash.data[0], 32)
        reduceScalar(cast[ptr cuchar](addr bytes[0]))
        copyMem(addr keyHash.data[0], addr bytes[0], 32)

        keyToNegativePoint(addr keyPoint, addr keys[k].data[0])
        serialize(addr bytes[0], addr keyPoint)
        keyToNegativePoint(addr keyPoint, cast[ptr cuchar](addr bytes[0]))

        multiplyScalar(
            addr a,
            cast[ptr cuchar](addr keyHash.data[0]),
            addr keyPoint,
            addr blankScalar[0]
        )

        serialize(addr bytes[0], addr a)
        keyToNegativePoint(addr keyPoint, cast[ptr cuchar](addr bytes[0]))
        serialize(addr bytes[0], addr keyPoint)
        keyToNegativePoint(addr keyPoint, cast[ptr cuchar](addr bytes[0]))

        if k == 0:
            res = keyPoint
        else:
            p3ToCached(addr tempCached, addr keyPoint)
            add(addr tempRes, addr res, addr tempCached)
            p1p1ToP3(addr res, addr tempRes)

    serialize(addr result.data[0], addr res)
