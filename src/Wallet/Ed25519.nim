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
    EdSeed* = Seed
    EdPrivateKey* = PrivateKey
    EdPublicKey* = PublicKey

#Seed constructor.
proc newEdSeed*(): Seed {.forceCheck: [
    RandomError
].} =
    #Fill the Seed with random bytes.
    try:
        randomFill(result)
    except RandomError:
        raise newException(RandomError, "Couldn't randomly fill the Seed.")

#Key Pair constrcutor.
func newEdKeyPair*(
    seedArg: Seed
): tuple[
    priv: PrivateKey,
    pub: PublicKey
] {.forceCheck: [
    SodiumError
], fcBoundsOverride.} =
    #Extract the Seed.
    var seed: Seed = seedArg

    #Call the C function and verify the result.
    if sodiumKeyPair(
        addr result.pub[0],
        addr result.priv[0],
        addr seed[0]
    ) != 0:
        raise newException(SodiumError, "Sodium could not create a Key Pair from the passed Seed.")

#Nim function for signing a message.
func sign*(
    key: PrivateKey,
    msgArg: string
): string {.forceCheck: [
    SodiumError
], fcBoundsOverride.} =
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
    result = newString(64)
    if sodiumSign(addr state, addr result[0], nil, key) != 0:
        raise newException(SodiumError, "Sodium could not sign a message.")

#Nim function for verifying a message.
func verify*(
    key: PublicKey,
    msgArg: string,
    sigArg: string
): bool {.forceCheck: [
    SodiumError
], fcBoundsOverride.} =
    #Extract the args.
    var
        msg: string = SIGN_PREFIX & msgArg
        sig: string = sigArg

    #Declare the State.
    var state: ED25519State
    if sodiumInitState(addr state) != 0:
        raise newException(SodiumError, "Sodium could not initiate a State.")

    #Update the State with the message.
    if sodiumUpdateState(addr state, addr msg[0], cast[culong](msg.len)) != 0:
        raise newException(SodiumError, "Sodium could not update a State.")

    #Verify the signature.
    if sodiumVerify(addr state, addr sig[0], key) != 0:
        return false

    result = true
