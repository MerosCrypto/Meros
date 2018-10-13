#Errors lib.
import Errors

#LibSodium lib.
import libsodium
#Export the Private/Public Key objects.
export Seed, PrivateKey, PublicKey

#Standard string utils lib.
import strutils

#Nimcrypto lib.
import nimcrypto

#SIGN_PREFIX applied to every message.
const SIGN_PREFIX {.strdefine.}: string = "EMB"

#Seed constructor.
proc newSeed*(): Seed {.raises: [RandomError].} =
    try:
        #Use nimcrypto to fill the Seed with random bytes.
        if randomBytes(result) != 32:
            raise newException(RandomError, "Couldn't get enough bytes for the Seed.")
    except:
        raise newException(RandomError, getCurrentExceptionMsg())

#Nim function for creating a Key Pair.
func newKeyPair*(seedArg: Seed): tuple[priv: PrivateKey, pub: PublicKey] {.raises: [SodiumError]} =
    #Extract the Seed.
    var seed: Seed = seedArg

    #Call the C function and verify the result.
    if sodiumKeyPair(
        addr result.pub[0],
        addr result.priv[0],
        addr seed[0]
    ) != 0:
        raise newException(SodiumError, "Sodium could not create a Key Pair.")

#Nim function for signing a message.
func sign*(key: PrivateKey, msgArg: string): string {.raises: [SodiumError]} =
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
    var sig: array[64, char]
    if sodiumSign(addr state, addr sig[0], nil, key) != 0:
        raise newException(SodiumError, "Sodium could not sign a message.")

    #Return the signature.
    return sig.join()

#Nim function for verifying a message.
func verify*(key: PublicKey, msgArg: string, sigArg: string): bool {.raises: [SodiumError]} =
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
