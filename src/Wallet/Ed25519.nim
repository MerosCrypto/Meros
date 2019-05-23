#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#LibSodium Ed25519 components.
import mc_ed25519

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

#Seed constructor.
proc newEdSeed*(): EdSeed {.forceCheck: [
    RandomError
].} =
    #Fill the Seed with random bytes.
    try:
        randomFill(result.data)
    except RandomError:
        raise newException(RandomError, "Couldn't randomly fill the Seed.")

#Key Pair constrcutor.
func newEdKeyPair*(
    seedArg: EdSeed
): tuple[
    priv: EdPrivateKey,
    pub: EdPublicKey
] {.forceCheck: [
    SodiumError
].} =
    #Extract the Seed.
    var seed: Seed = seedArg.data

    #Call the C function and verify the result.
    if sodiumKeyPair(
        addr result.pub.data[0],
        addr result.priv.data[0],
        addr seed[0]
    ) != 0:
        raise newException(SodiumError, "Sodium could not create a Key Pair from the passed Seed.")

#Nim function for signing a message.
func sign*(
    key: EdPrivateKey,
    msgArg: string
): EdSignature {.forceCheck: [
    SodiumError
].} =
    #Extract the message arg.
    var msg: string = SIGN_PREFIX & msgArg

    #Declare the State.
    var state: ED25519State
    if sodiumInitState(addr state) != 0:
        raise newException(SodiumError, "Sodium could not initiate a State.")

    #Update the State with the message.
    if sodiumUpdateState(addr state, addr msg[0], cast[culong](msg.len)) != 0:
        raise newException(SodiumError, "Sodium could not update a State.")

    #Create the signature.
    if sodiumSign(addr state, cast[ptr char](addr result.data[0]), nil, key.data) != 0:
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
    var state: ED25519State
    if sodiumInitState(addr state) != 0:
        raise newException(SodiumError, "Sodium could not initiate a State.")

    #Update the State with the message.
    if sodiumUpdateState(addr state, addr msg[0], cast[culong](msg.len)) != 0:
        raise newException(SodiumError, "Sodium could not update a State.")

    #Verify the signature.
    if sodiumVerify(addr state, cast[ptr char](addr sig.data[0]), key.data) != 0:
        return false

    result = true
