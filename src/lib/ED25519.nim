#LibSodium lib.
import libsodium
#Export the Private/Public Key objects.
export PrivateKey, PublicKey

#Standard string utils lib.
import strutils

#Nim function for creating a Key Pair.
proc newKeyPair*(): tuple[priv: PrivateKey, pub: PublicKey] {.raises: [Exception]} =
    #Call the C function and verify the result.
    if sodiumKeyPair(
        addr result.pub[0],
        addr result.priv[0]
    ) != 0:
        raise newException(Exception, "Sodium could not create a Key Pair.")

#Nim function for creating a Public Key.
proc newPublicKey*(keyArg: PrivateKey): PublicKey {.raises: [Exception]} =
    #Extract the Private Key arg.
    var key: PrivateKey = keyArg

    #Call the C function and verify the result.
    if sodiumPublicKey(
        addr result[0],
        addr key[0]
    ) != 0:
        raise newException(Exception, "Sodium could not create a Public Key.")

#Nim function for signing a message.
proc sign*(key: PrivateKey, msgArg: string): string {.raises: [Exception]} =
    #Extract the message arg.
    var msg: string = "EMB" & msgArg

    #Declare the State.
    var state: ED25519State
    if sodiumInitState(addr state) != 0:
        raise newException(Exception, "Sodium could not initiate a State.")

    #Update the State with the message.
    if sodiumUpdateState(addr state, addr msg[0], cast[culong](msg.len)) != 0:
        raise newException(Exception, "Sodium could not update a State.")

    #Create the signature.
    var sig: array[64, char]
    if sodiumSign(addr state, addr sig[0], nil, key) != 0:
        raise newException(Exception, "Sodium could not sign a message.")

    #Return the signature.
    return sig.join()

#Nim function for verifying a message.
proc verify*(key: PublicKey, msgArg: string, sigArg: string): bool {.raises: [Exception]} =
    #Extract the args.
    var
        msg: string = "EMB" & msgArg
        sig: string = sigArg

    #Declare the State.
    var state: ED25519State
    if sodiumInitState(addr state) != 0:
        raise newException(Exception, "Sodium could not initiate a State.")

    #Update the State with the message.
    if sodiumUpdateState(addr state, addr msg[0], cast[culong](msg.len)) != 0:
        raise newException(Exception, "Sodium could not update a State.")

    #Verify the signature.
    if sodiumVerify(addr state, addr sig[0], key) != 0:
        return false

    result = true
