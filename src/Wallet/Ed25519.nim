#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Ed25519 library.
import mc_ed25519

#SIGN_PREFIX applied to every message, stopping cross-network replays.
const SIGN_PREFIX {.strdefine.}: string = "MEROS"

#Export the Private/Public Key objects (with a prefix).
type
    EdPoint* = Point
    EdPrivateKey* = object
        data*: PrivateKey
    EdPublicKey* = object
        data*: PublicKey
    EdSignature* = object
        data*: array[64, uint8]

proc toPublicKey*(
    keyArg: EdPrivateKey
): EdPublicKey {.forceCheck: [].} =
    var
        #Extract the key argument.
        key: EdPrivateKey = keyArg
        #Public Key point.
        publicKeyPoint: ptr EdPoint = cast[ptr EdPoint](alloc0(sizeof(EdPoint)))

    #Multiply the Public Key against the base.
    multiplyBase(publicKeyPoint, addr key.data[0])
    serialize(addr result.data[0], publicKeyPoint)

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
    sign(cast[ptr cuchar](addr result.data[0]), cast[ptr cuchar](addr msg[0]), csize(msg.len), cast[ptr cuchar](addr privKey.data[0]), addr pubKey.data[0])

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

    if verify(cast[ptr cuchar](addr sig.data[0]), cast[ptr cuchar](addr msg[0]), csize(msg.len), addr key.data[0]) != 0:
        return false

    result = true
