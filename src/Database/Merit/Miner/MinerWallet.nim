#Errors lib.
import ../../../lib/Errors

#nimcrypto; used to generate a valid seed.
import nimcrypto

#BLS lib.
import BLS
#Export the key objects.
export PrivateKey, PublicKey, Signature

#Finals lib.
import finals

#String utils standard lib.
import strutils

finalsd:
    #Miner object.
    type MinerWallet* = ref object of RootObj
        #Private Key.
        privateKey* {.final.}: PrivateKey
        #Public Key.
        publicKey* {.final.}: PublicKey

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

    var priv: PrivateKey
    try:
        priv = newPrivateKeyFromSeed(seed)
    except:
        raise newException(BLSError, "Couldn't create a Private Key. " & getCurrentExceptionMsg())

    result = MinerWallet(
        privateKey: priv,
        publicKey: priv.getPublicKey()
    )

proc newMinerWallet*(key: string): MinerWallet {.raises: [BLSError].} =
    var priv: PrivateKey
    try:
        priv = newPrivateKeyFromSeed(key)
    except:
        raise newException(BLSError, "Couldn't create a Private Key.")

    result = MinerWallet(
        privateKey: priv,
        publicKey: priv.getPublicKey()
    )

#Sign a message via a MinerWallet.
func sign*(miner: MinerWallet, msg: string): Signature {.raises: [].} =
    miner.privateKey.sign(msg)

#Verify a message.
func verify*(
    miner: MinerWallet,
    msg: string,
    sigArg: string
): bool {.raises: [BLSError].} =
    #Create the Signature.
    var sig: Signature
    try:
        sig = newSignatureFromBytes(sigArg)
    except:
        raise newException(BLSError, "Couldn't load a BLS Signature from bytes.")

    #Create the Aggregation Info.
    var agInfo: AggregationInfo = newAggregationInfoFromMsg(miner.publicKey, msg)

    #Add the Aggregation Info to the signature.
    sig.setAggregationInfo(agInfo)

    #Verify the signature.
    result = sig.verify()
