#Errors lib.
import ../lib/Errors

#Ed25519 lib.
import ../lib/Ed25519
#Export the critical objects.
export EdSeed, EdPrivateKey, EdPublicKey

#Address lib.
import Address
#Export the Address lib.
export Address

#Finals lib.
import finals

#String utils standard lib.
import strutils

finalsd:
    #Wallet object.
    type Wallet* = ref object of RootObj
        #Seed.
        seed* {.final.}: EdSeed
        #Private Key.
        privateKey* {.final.}: EdPrivateKey
        #Public Key.
        publicKey* {.final.}: EdPublicKey
        #Address.
        address* {.final.}: string

#Create a new Seed from a string.
func newEdSeed*(seed: string): EdSeed {.raises: [ValueError].} =
    #If it's binary...
    if seed.len == 32:
        for i in 0 ..< 32:
            result[i] = seed[i]
    #If it's hex...
    elif seed.len == 64:
        for i in countup(0, 63, 2):
            result[i div 2] = cuchar(parseHexInt(seed[i .. i + 1]))
    else:
        raise newException(ValueError, "Invalid Seed.")

#Create a new Public Key from a string.
func newEdPublicKey*(key: string): EdPublicKey {.raises: [ValueError].} =
    #If it's binary...
    if key.len == 32:
        for i in 0 ..< 32:
            result[i] = key[i]
    #If it's hex...
    elif key.len == 64:
        for i in countup(0, 63, 2):
            result[i div 2] = cuchar(parseHexInt(key[i .. i + 1]))
    else:
        raise newException(ValueError, "Invalid Public Key.")

#Stringify a Seed/PublicKey.
func toString*(key: EdSeed | EdPublicKey): string {.raises: [].} =
    result = ""
    for b in key:
        result = result & char(b)
func `$`*(key: EdSeed | EdPublicKey): string {.raises: [].} =
    result = key.toString().toHex()

#Constructor.
func newWallet*(
    seed: EdSeed = newEdSeed()
): Wallet {.raises: [ValueError, SodiumError].} =
    #Generate a new key pair.
    var pair: tuple[priv: EdPrivateKey, pub: EdPublicKey] = newEdKeyPair(seed)

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

#Constructor.
func newWallet*(
    seed: EdSeed,
    address: string
): Wallet {.raises: [ValueError, SodiumError].} =
    #Create a Wallet based off the Seed (and verify the integrity via the Address).
    result = newWallet(seed)

    #Verify the integrity via the Address.
    if result.address != address:
        raise newException(ValueError, "Invalid Address for this Wallet.")

#Sign a message.
func sign*(key: EdPrivateKey, msg: string): string {.raises: [SodiumError].} =
    Ed25519.sign(key, msg)

#Sign a message via a Wallet.
func sign*(wallet: Wallet, msg: string): string {.raises: [SodiumError].} =
    wallet.privateKey.sign(msg)

#Verify a message.
func verify*(
    key: EdPublicKey,
    msg: string,
    sig: string
): bool {.raises: [SodiumError].} =
    Ed25519.verify(key, msg, sig)

#Verify a message via a Wallet.
func verify*(
    wallet: Wallet,
    msg: string,
    sig: string
): bool {.raises: [SodiumError].} =
    wallet.publicKey.verify(msg, sig)
