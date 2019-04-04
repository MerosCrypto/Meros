#Errors lib.
import ../lib/Errors

#BLS lib.
import ../lib/BLS

#Finals lib.
import finals

#nimcrypto; used to generate a valid seed.
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
proc newMinerWallet*(): MinerWallet {.raises: [RandomError, BLSError].} =
    #Create a seed.
    var seed: string = newString(32)
    try:
        #Use nimcrypto to fill the Seed with random bytes.
        if randomBytes(seed) != 32:
            raise newException(RandomError, "Couldn't get enough bytes for the Seed.")
    except:
        raise newException(RandomError, getCurrentExceptionMsg())

    var priv: BLSPrivateKey = newBLSPrivateKeyFromSeed(seed)

    result = MinerWallet(
        privateKey: priv,
        publicKey: priv.getPublicKey()
    )
    result.ffinalizePrivateKey()
    result.ffinalizePublicKey()

proc newMinerWallet*(priv: BLSPrivateKey): MinerWallet {.raises: [BLSError].} =
    result = MinerWallet(
        privateKey: priv,
        publicKey: priv.getPublicKey()
    )
    result.ffinalizePrivateKey()
    result.ffinalizePublicKey()

#Sign a message via a MinerWallet.
proc sign*(miner: MinerWallet, msg: string): BLSSignature {.raises: [BLSError].} =
    miner.privateKey.sign(msg)

#Verify a message.
proc verify*(
    miner: MinerWallet,
    msg: string,
    sigArg: string
): bool {.raises: [BLSError].} =
    #Create the Signature.
    var sig: BLSSignature = newBLSSignature(sigArg)

    #Create the Aggregation Info.
    var agInfo: BLSAggregationInfo = newBLSAggregationInfo(miner.publicKey, msg)

    #Add the Aggregation Info to the signature.
    sig.setAggregationInfo(agInfo)

    #Verify the signature.
    result = sig.verify()
