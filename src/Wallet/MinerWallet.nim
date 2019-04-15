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
        #Private Key.
        privateKey* {.final.}: BLSPrivateKey
        #Public Key.
        publicKey* {.final.}: BLSPublicKey

#Constructors.
proc newMinerWallet*(
    priv: BLSPrivateKey
): MinerWallet {.forceCheck: [
    BLSError
].} =
    try:
        result = MinerWallet(
            initiated: true,
            privateKey: priv,
            publicKey: priv.getPublicKey()
        )
    except BLSError as e:
        raise e
    result.ffinalizeInitiated()
    result.ffinalizePrivateKey()
    result.ffinalizePublicKey()

proc newMinerWallet*(): MinerWallet {.forceCheck: [
    RandomError,
    BLSError
].} =
    #Create a seed.
    var seed: string = newString(32)
    #Use nimcrypto to fill the Seed with random bytes.
    try:
        randomFill(seed)
    except RandomError:
        raise newException(RandomError, "Couldn't randomly fill the BLS Seed.")

    try:
        result = newMinerWallet(newBLSPrivateKeyFromSeed(seed))
    except BLSError as e:
        raise e

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
        raise e
