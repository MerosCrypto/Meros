#Errors lib.
import ../lib/Errors

#ED25519 lib.
import ../lib/ED25519
#Export the key objects.
export PrivateKey, PublicKey

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
        #Private Key.
        privateKey* {.final.}: PrivateKey
        #Public Key.
        publicKey* {.final.}: PublicKey
        #Address.
        address* {.final.}: string

#Create a new Private Key from a string.
proc newPrivateKey*(key: string): PrivateKey {.raises: [ValueError].} =
    #If it's binary...
    if key.len == 64:
        for i in 0 ..< 64:
            result[i] = key[i]
    #If it's hex...
    elif key.len == 128:
        for i in countup(0, 127, 2):
            result[i div 2] = cuchar(parseHexInt(key[i .. i + 1]))
    else:
        raise newException(ValueError, "Invalid Private Key.")

#Create a new Public Key from a string.
proc newPublicKey*(key: string): PublicKey {.raises: [ValueError].} =
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

#Stringify a Private Key.
proc `$`*(key: PrivateKey): string {.raises: [].} =
    result = ""
    for i in 0 ..< 64:
        result = result & uint8(key[i]).toHex()

#Stringify a Public Key to it's hex representation.
proc `$`*(key: PublicKey): string {.raises: [].} =
    result = ""
    for i in 0 ..< 32:
        result = result & uint8(key[i]).toHex()

#Constructor.
proc newWallet*(): Wallet {.raises: [ValueError, SodiumError].} =
    #Generate a new key pair.
    var pair: tuple[priv: PrivateKey, pub: PublicKey] = newKeyPair()

    #Create a new Wallet based off that key pair.
    result = Wallet(
        privateKey: pair.priv,
        publicKey: pair.pub,
        address: newAddress(pair.pub)
    )

#Constructor.
proc newWallet*(
    privateKey: PrivateKey
): Wallet {.raises: [ValueError, SodiumError].} =
    #Create a new Wallet based off the passed in Private Key.
    result = Wallet(
        privateKey: privateKey,
        publicKey:  newPublicKey(privateKey)
    )
    #Set the address based off the created Public Key.
    result.address = newAddress(result.publicKey)

#Constructor.
proc newWallet*(
    privateKey: PrivateKey,
    publicKey: PublicKey
): Wallet {.raises: [ValueError, SodiumError].} =
    #Create a Wallet based off the Private Key.
    result = newWallet(privateKey)
    #Verify the integrity via the Public Key.
    if result.publicKey != publicKey:
        raise newException(ValueError, "Invalid Public Key for this Private Key.")

#Constructor.
proc newWallet*(
    privateKey: PrivateKey,
    publicKey: PublicKey,
    address: string
): Wallet {.raises: [ValueError, SodiumError].} =
    #Create a Wallet based off the Private Key (and verify the integrity via the Public Key).
    result = newWallet(privateKey, publicKey)
    #Verify the integrity via the Address.
    if result.address != address:
        raise newException(ValueError, "Invalid Address for this Public Key.")

#Sign a message.
proc sign*(key: PrivateKey, msg: string): string {.raises: [SodiumError].} =
    ED25519.sign(key, msg)

#Sign a message via a Wallet.
proc sign*(wallet: Wallet, msg: string): string {.raises: [SodiumError].} =
    wallet.privateKey.sign(msg)

#Verify a message.
proc verify*(
    key: PublicKey,
    msg: string,
    sig: string
): bool {.raises: [SodiumError].} =
    ED25519.verify(key, msg, sig)

#Verify a message via a Wallet.
proc verify*(
    wallet: Wallet,
    msg: string,
    sig: string
): bool {.raises: [SodiumError].} =
    wallet.publicKey.verify(msg, sig)
