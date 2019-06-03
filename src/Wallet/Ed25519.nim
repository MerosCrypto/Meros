#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#LibSodium Ed25519 components.
import mc_ed25519
export multiplyBase

#SIGN_PREFIX applied to every message, stopping cross-network replays.
const SIGN_PREFIX {.strdefine.}: string = "MEROS"

#Export the Private/Public Key objects (with a prefix).
type
    EdSeed* = object
        data*: Seed
    EdPrivateKey* = object
        data*: PrivateKey
    EdPublicKey* = object
        data*: PublicKey
    EdSignature* = object
        data*: array[64, uint8]

#Seed constructors.
proc newEdSeed*(): EdSeed {.forceCheck: [
    RandomError
].} =
    #Fill the Seed with random bytes.
    try:
        randomFill(result.data)
    except RandomError:
        raise newException(RandomError, "Couldn't randomly fill the Seed.")

func newEdSeed*(
    seed: string
): EdSeed {.forceCheck: [
    EdSeedError
].} =
    #If it's binary...
    if seed.len == 32:
        for i in 0 ..< 32:
            result.data[i] = seed[i]
    #If it's hex...
    elif seed.len == 64:
        try:
            for i in countup(0, 63, 2):
                result.data[i div 2] = cuchar(parseHexInt(seed[i .. i + 1]))
        except ValueError:
            raise newException(EdSeedError, "Hex-length Seed with invalid Hex data passed to newEdSeed.")
    else:
        raise newException(EdSeedError, "Invalid length Seed passed to newEdSeed.")

#Nim function for signing a message.
func sign*(
    keyArg: EdPrivateKey,
    msgArg: string
): EdSignature {.forceCheck: [
    SodiumError
].} =
    #Extract the arguments.
    var
        key: EdPrivateKey = keyArg
        msg: string = SIGN_PREFIX & msgArg

    #Create the signature.
    if sign(cast[ptr char](addr result.data[0]), nil, addr msg[0], culonglong(msg.len), cast[ptr cuchar](addr key.data[0])) != 0:
        raise newException(SodiumError, "Sodium could not sign a message.")

#Nim function for verifying a message.
func verify*(
    key: EdPublicKey,
    msgArg: string,
    sigArg: EdSignature
): bool {.forceCheck: [
    SodiumError
].} =
    #Extract the args.
    var
        msg: string = SIGN_PREFIX & msgArg
        sig: EdSignature = sigArg

    #Declare the State.
    var state: State
    if init(addr state) != 0:
        raise newException(SodiumError, "Sodium could not initiate a State.")

    #Update the State with the message.
    if update(addr state, addr msg[0], cast[culong](msg.len)) != 0:
        raise newException(SodiumError, "Sodium could not update a State.")

    #Verify the signature.
    if verify(addr state, cast[ptr char](addr sig.data[0]), key.data) != 0:
        return false

    result = true
