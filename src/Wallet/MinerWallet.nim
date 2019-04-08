#Errors lib.
import ../lib/Errors

#BLS lib.
import ../lib/BLS

#Finals lib.
import finals

#nimcrypto lib, used for its secure random number generation.
import nimcrypto

#String utils standard lib.
import strutils

finalsd:
    #Miner object.
    type MinerWallet* = ref object of RootObj
        #Private Key.
        privateKey* {.final.}: BLSPrivateKey
        #Public Key.
        publicKey* {.final.}: BLSPublicKey

#Constructors.
proc newMinerWallet*(): MinerWallet {.forceCheck: [
    RandomError,
    BLSError
].} =
    #Create a seed.
    var seed: string = newString(32)
    try:
        #Use nimcrypto to fill the Seed with random bytes.
        if randomBytes(seed) != 32:
            raise newException(RandomError, "Couldn't get enough bytes for the Seed.")
    except:
        raise newException(RandomError, getCurrentExceptionMsg())

    try:
        var priv: BLSPrivateKey = newBLSPrivateKeyFromSeed(seed)
        result = MinerWallet(
            privateKey: priv,
            publicKey: priv.getPublicKey()
        )
    except BLSError:
        fcRaise BLSError
    result.ffinalizePrivateKey()
    result.ffinalizePublicKey()

proc newMinerWallet*(
    priv: BLSPrivateKey
): MinerWallet {.forceCheck: [
    BLSError
].} =
    try:
        result = MinerWallet(
            privateKey: priv,
            publicKey: priv.getPublicKey()
        )
    except BLSError:
        fcRaise BLSError
    result.ffinalizePrivateKey()
    result.ffinalizePublicKey()

#Sign a message via a MinerWallet.
proc sign*(
    miner: MinerWallet,
    msg: string
): BLSSignature {.forceCheck: [
    BLSError
].} =
    try:
        result = miner.privateKey.sign(msg)
    except:
        fcRaise BLSError
