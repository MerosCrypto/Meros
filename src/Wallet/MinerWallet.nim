#Errors lib.
import ../lib/Errors

#BLS lib.
import BLS
export BLS

#Finals lib.
import finals

finalsd:
    #Miner object.
    type MinerWallet* = object
        #Private Key.
        privateKey* {.final.}: BLSPrivateKey
        #Public Key.
        publicKey* {.final.}: BLSPublicKey

#Constructors.
func newMinerWallet*(): MinerWallet {.forceCheck: [
    RandomError,
    BLSError
].} =
    #Create a seed.
    var seed: string = newString(32)
    #Use nimcrypto to fill the Seed with random bytes.
    try:
        randomFill(seed)
    except:
        raise newException(RandomError, "Couldn't randomly fill the BLS Seed.")

    try:
        var priv: BLSPrivateKey = newBLSPrivateKeyFromSeed(seed)
        result = MinerWallet(
            privateKey: priv,
            publicKey: priv.getPublicKey()
        )
    except BLSError as e:
        raise e
    result.ffinalizePrivateKey()
    result.ffinalizePublicKey()

func newMinerWallet*(
    priv: BLSPrivateKey
): MinerWallet {.forceCheck: [
    BLSError
].} =
    try:
        result = MinerWallet(
            privateKey: priv,
            publicKey: priv.getPublicKey()
        )
    except BLSError as e:
        raise e
    result.ffinalizePrivateKey()
    result.ffinalizePublicKey()

#Sign a message via a MinerWallet.
func sign*(
    miner: MinerWallet,
    msg: string
): BLSSignature {.forceCheck: [
    BLSError
].} =
    try:
        result = miner.privateKey.sign(msg)
    except BLSError as e:
        raise e
