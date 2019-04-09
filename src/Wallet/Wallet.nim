#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Ed25519 lib.
import Ed25519
#Export the critical objects.
export EdSeed, EdPrivateKey, EdPublicKey

#Address lib.
import Address
#Export the Address lib.
export Address

#Finals lib.
import finals

finalsd:
    #Wallet object.
    type Wallet* = object
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
            result[i] = seed[i]
    #If it's hex...
    elif seed.len == 64:
        try:
            for i in countup(0, 63, 2):
                result[i div 2] = cuchar(parseHexInt(seed[i .. i + 1]))
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
            result[i] = key[i]
    #If it's hex...
    elif key.len == 64:
        try:
            for i in countup(0, 63, 2):
                result[i div 2] = cuchar(parseHexInt(key[i .. i + 1]))
        except ValueError:
            raise newException(EdPublicKeyError, "Hex-length Public Key with invalid Hex data passed to newEdSeed.")
    else:
        raise newException(EdPublicKeyError, "Invalid length Public Key passed to newEdPublicKey.")

#Stringify a Seed/PublicKey.
func toString*(
    key: EdSeed or EdPublicKey
): string {.forceCheck: [].} =
    for b in key:
        result = result & char(b)
func `$`*(
    key: EdSeed or EdPublicKey
): string {.forceCheck: [].} =
    key.toString().toHex()

#Constructor.
proc newWallet*(
    seed: EdSeed
): Wallet {.forceCheck: [
    SodiumError
].} =
    #Generate a new key pair.
    var pair: tuple[priv: EdPrivateKey, pub: EdPublicKey]
    try:
        pair = newEdKeyPair(seed)
    except SodiumError:
        fcRaise SodiumError

    #Create a new Wallet based off the seed/key pair.
    result = Wallet(
        seed: seed,
        privateKey: pair.priv,
        publicKey: pair.pub,
        address: newAddress(pair.pub)
    )
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
    except RandomError:
        fcRaise RandomError
    except SodiumError:
        fcRaise SodiumError

#Constructor.
proc newWallet*(
    seed: EdSeed,
    address: string
): Wallet {.forceCheck: [
    AddressError,
    SodiumError
].} =
    #Create a Wallet based off the Seed (and verify the integrity via the Address).
    try:
        result = newWallet(seed)
    except SodiumError:
        fcRaise SodiumError

    #Verify the integrity via the Address.
    if address.isValid(result.publicKey):
        raise newException(AddressError, "Invalid Address for this Wallet.")

#Sign a message via a Wallet.
proc sign*(
    wallet: Wallet,
    msg: string
): string {.forceCheck: [
    SodiumError
].} =
    try:
        result = wallet.privateKey.sign(msg)
    except SodiumError:
        fcRaise SodiumError

#Verify a signature.
proc verify*(
    key: EdPublicKey,
    msg: string,
    sig: string
): bool {.forceCheck: [
    SodiumError
].} =
    try:
        result = Ed25519.verify(key, msg, sig)
    except SodiumError:
        fcRaise SodiumError

#Verify a signature via a Wallet.
proc verify*(
    wallet: Wallet,
    msg: string,
    sig: string
): bool {.forceCheck: [
    SodiumError
].} =
    try:
        result = wallet.publicKey.verify(msg, sig)
    except SodiumError:
        fcRaise SodiumError
