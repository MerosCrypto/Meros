#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#BLS lib.
import BLS
export BLS

#Finals lib.
import finals

finalsd:
    #Miner object.
    type MinerWallet* = object
        #Initiated.
        initiated* {.final.}: bool
        #Seed.
        seed* {.final.}: string
        #Private Key.
        privateKey* {.final.}: BLSPrivateKey
        #Public Key.
        publicKey* {.final.}: BLSPublicKey

#Constructors.
proc newMinerWallet*(
    seedArg: string
): MinerWallet {.forceCheck: [
    ValueError,
    BLSError
].} =
    var seed: string
    if seedArg.len == 48:
        seed = seedArg
    elif seedArg.len == 96:
        try:
            seed = seedArg.parseHexStr()
        except ValueError:
            raise newException(ValueError, "Hex-length Seed with invalid Hex data passed to newMinerWallet.")
    else:
        raise newException(ValueError, "Seed was of an invalid length.")

    try:
        result = MinerWallet(
            initiated: true,
            seed: seed,
            privateKey: newBLSPrivateKeyFromSeed(seed)
        )
        result.publicKey = result.privateKey.getPublicKey()
    except BLSError as e:
        fcRaise e
    result.ffinalizeInitiated()
    result.ffinalizePrivateKey()
    result.ffinalizeSeed()
    result.ffinalizePublicKey()

proc newMinerWallet*(): MinerWallet {.forceCheck: [
    ValueError,
    RandomError,
    BLSError
].} =
    #Create a seed.
    var seed: string = newString(48)
    #Use nimcrypto to fill the Seed with random bytes.
    try:
        randomFill(seed)
    except RandomError:
        raise newException(RandomError, "Couldn't randomly fill the BLS Seed.")

    try:
        result = newMinerWallet(seed)
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

#Sign a message via a MinerWallet.
proc sign*(
    miner: MinerWallet,
    msg: string
): BLSSignature {.forceCheck: [
    BLSError
].} =
    try:
        result = miner.privateKey.sign(msg)
    except BLSError as e:
        fcRaise e
