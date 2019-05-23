#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Ed25519 lib.
import Ed25519
#Export the objects.
export EdSeed, EdPublicKey, EdSignature

#Address lib.
import Address
#Export the Address lib.
export Address

#Finals lib.
import finals

finalsd:
    #Wallet object.
    type Wallet* = object
        #Initiated.
        initiated* {.final.}: bool
        #Seed.
        seed* {.final.}: EdSeed
        #Private Key.
        privateKey* {.final.}: EdPrivateKey
        #Public Key.
        publicKey* {.final.}: EdPublicKey
        #Address.
        address* {.final.}: string

#Create a new Seed from a string.
func newEdSeed*(
    seed: string
): EdSeed {.forceCheck: [
    EdSeedError
].} =
    #If it's binary...
    if seed.len == 32:
        for i in 0 ..< 32:
            result.data[i] = seed[i]
    #If it's hex...
    elif seed.len == 64:
        try:
            for i in countup(0, 63, 2):
                result.data[i div 2] = cuchar(parseHexInt(seed[i .. i + 1]))
        except ValueError:
            raise newException(EdSeedError, "Hex-length Seed with invalid Hex data passed to newEdSeed.")
    else:
        raise newException(EdSeedError, "Invalid length Seed passed to newEdSeed.")

#Create a new Public Key from a string.
func newEdPublicKey*(
    key: string
): EdPublicKey {.forceCheck: [
    EdPublicKeyError
].} =
    #If it's binary...
    if key.len == 32:
        for i in 0 ..< 32:
            result.data[i] = key[i]
    #If it's hex...
    elif key.len == 64:
        try:
            for i in countup(0, 63, 2):
                result.data[i div 2] = cuchar(parseHexInt(key[i .. i + 1]))
        except ValueError:
            raise newException(EdPublicKeyError, "Hex-length Public Key with invalid Hex data passed to newEdSeed.")
    else:
        raise newException(EdPublicKeyError, "Invalid length Public Key passed to newEdPublicKey.")

#Create a new Signature from a string.
func newEdSignature*(
    sigArg: string
): EdSignature {.forceCheck: [].} =
    var sig: string = sigArg
    copyMem(addr result.data[0], addr sig[0], 64)

#Stringify a Seed/PublicKey/Signature.
func toString*(
    data: EdSeed or EdPublicKey or EdSignature
): string {.forceCheck: [].} =
    for b in data.data:
        result = result & char(b)

func `$`*(
    data: EdSeed or EdPublicKey or EdSignature
): string {.inline, forceCheck: [].} =
    data.toString().toHex()

#Constructor.
func newWallet*(
    seed: EdSeed
): Wallet {.forceCheck: [
    SodiumError
].} =
    #Generate a new key pair.
    var pair: tuple[priv: EdPrivateKey, pub: EdPublicKey]
    try:
        pair = newEdKeyPair(seed)
    except SodiumError as e:
        fcRaise e

    #Create a new Wallet based off the seed/key pair.
    result = Wallet(
        initiated: true,
        seed: seed,
        privateKey: pair.priv,
        publicKey: pair.pub,
        address: newAddress(pair.pub)
    )
    result.ffinalizeInitiated()
    result.ffinalizeSeed()
    result.ffinalizePrivateKey()
    result.ffinalizePublicKey()
    result.ffinalizeAddress()

proc newWallet*(): Wallet {.forceCheck: [
    RandomError,
    SodiumError
].} =
    try:
        result = newWallet(newEdSeed())
    except RandomError as e:
        fcRaise e
    except SodiumError as e:
        fcRaise e

#Constructor.
func newWallet*(
    seed: EdSeed,
    address: string
): Wallet {.forceCheck: [
    AddressError,
    SodiumError
].} =
    #Create a Wallet based off the Seed (and verify the integrity via the Address).
    try:
        result = newWallet(seed)
    except SodiumError as e:
        fcRaise e

    #Verify the integrity via the Address.
    if not Address.isValid(address, result.publicKey):
        raise newException(AddressError, "Invalid Address for this Wallet.")

#Sign a message via a Wallet.
func sign*(
    wallet: Wallet,
    msg: string
): EdSignature {.forceCheck: [
    SodiumError
].} =
    try:
        result = wallet.privateKey.sign(msg)
    except SodiumError as e:
        fcRaise e

#Verify a signature.
func verify*(
    key: EdPublicKey,
    msg: string,
    sig: EdSignature
): bool {.forceCheck: [].} =
    try:
        result = Ed25519.verify(key, msg, sig)
    except SodiumError:
        return false

#Verify a signature via a Wallet.
func verify*(
    wallet: Wallet,
    msg: string,
    sig: EdSignature
): bool {.forceCheck: [].} =
    try:
        result = wallet.publicKey.verify(msg, sig)
    except SodiumError:
        return false
