#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Hash lib.
import ../lib/Hash

#Ed25519 lib.
import Ed25519

#Wallet lib.
import Wallet
export Wallet

#StInt lib.
import StInt

#Finals lib.
import finals

#Math standard lib.
import math

let
    #Ed25519's l value.
    l: StUInt[256] = "7237005577332262213973186563042994240857116359379907606001950938285454250989".parse(StUInt[256])
    #2^256.
    TwoTwoFiftySix: StUInt[512] = "0000000000000000000000000000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".parse(StUInt[512], 16)

finalsd:
    #HDWallet.
    type HDWallet* = object of Wallet
            #Child index on the parent.
            i* {.final.}: uint32
            #Chain Code.
            chainCode* {.final.}: SHA2_256Hash

#Constructors.
proc newHDWallet*(
    secretArg: string
): HDWallet {.forceCheck: [
    ValueError
].} =
    #Parse the secret.
    var secret: string = secretArg
    if secret.len == 64:
        try:
            secret = secretArg.parseHexStr()
        except ValueError:
            raise newException(ValueError, "Hex-length secret with invalid Hex data passed to newHDWallet.")

    #Keys.
    var
        privateKey: EdPrivateKey
        publicKey: EdPublicKey

    #Create the Private Key.
    privateKey.data = cast[array[64, cuchar]](SHA2_512(secret).data)
    if (uint8(privateKey.data[31]) and 0b00100000) != 0:
        raise newException(ValueError, "Secret generated an invalid private key,")
    privateKey.data[0]  = cuchar(uint8(privateKey.data[0])  and (not uint8(0b00000111)))
    privateKey.data[31] = cuchar(uint8(privateKey.data[31]) and (not uint8(0b10000000)))
    privateKey.data[31] = cuchar(uint8(privateKey.data[31]) or             0b01000000)

    #Create the Public Key.
    multiplyBase(addr publicKey.data[0], addr privateKey.data[0])

    result = HDWallet(
        #Set the Wallet fields.
        initiated: true,
        privateKey: privateKey,
        publicKey: publicKey,
        address: newAddress(publicKey),

        #Set the index to 0.
        i: 0,
        #Create the chain code.
        chainCode: SHA2_256('\1' & secret),
    )
    result.ffinalizeI()
    result.ffinalizeChainCode()

proc newHDWallet*(): HDWallet {.forceCheck: [
    RandomError
].} =
    try:
        result = newHDWallet(newEdSeed().toString())
    except RandomError as e:
        fcRaise e
    except ValueError:
        result = newHDWallet()

proc newHDWallet*(
    secret: string,
    chainCode: SHA2_256Hash
): HDWallet {.forceCheck: [
    ValueError
].} =
    try:
        result = newHDWallet(secret)
    except ValueError as e:
        fcRaise e
    if result.chainCode != chainCode:
        raise newException(ValueError, "Created an HDWallet yet the created wallet doesn't match the provided chain code.")

#Derive a Child HD Wallet.
proc derive*(
    wallet: HDWallet,
    childArg: uint32
): HDWallet {.forceCheck: [
    ValueError
].} =
    var
        #Parent properties, serieslized in little endian.
        pChainCode: string = wallet.chainCode.toString()
        pPrivateKey: string = wallet.privateKey.toString()
        pPrivateKeyL: array[32, uint8]
        pPrivateKeyR: array[64, uint8]
        pPublicKey: string = wallet.publicKey.toString()

        #Child index, in little endian.
        child: string = childArg.toBinary().pad(4).reverse()
        #Is this a Hardened derivation?
        hardened: bool = childArg >= (uint32(2) ^ 31)
    for i in 0 ..< 32:
        pPrivateKeyL[31 - i] = uint8(pPrivateKey[i])
        pPrivateKeyR[63 - i] = uint8(pPrivateKey[32 + i])

    #Calculate Z and the Chaincode.
    var
        Z: SHA2_512Hash
        chainCodeExtended: SHA2_512Hash
        chainCode: SHA2_256Hash
    if hardened:
        Z = HMAC_SHA2_512(pChainCode, '\0' & pPrivateKey & child)
        chainCodeExtended = HMAC_SHA2_512(pChainCode, '\1' & pPrivateKey & child)
        copyMem(addr chainCode.data[0], addr chainCodeExtended.data[32], 32)
    else:
        Z = HMAC_SHA2_512(pChainCode, '\2' & pPublicKey & child)
        chainCodeExtended = HMAC_SHA2_512(pChainCode, '\3' & pPublicKey & child)
        copyMem(addr chainCode.data[0], addr chainCodeExtended.data[32], 32)

    var
        #Z left and right.
        zL: array[32, uint8]
        zR: array[64, uint8]
        #Key left and right.
        kL: StUInt[256]
        kR: StUInt[512]
    for i in 0 ..< 28:
        zL[31 - i] = Z.data[i]
    for i in 32 ..< 64:
        zR[63 - (i - 32)] = Z.data[i]

    #Calculate the Private Key.
    try:
        kL = (readUIntBE[256](zL) * 8) + readUIntBE[256](pPrivateKeyL)
    except OverflowError:
        raise newException(ValueError, "Deriving this child key caused an overflow when calculating kL.")
    try:
        if kL mod l == 0:
            raise newException(ValueError, "Deriving this child key produced an unusable PrivateKey.")
    except DivByZeroError:
        doAssert(false, "Performing a modulus of Ed25519's l raised a DivByZeroError.")

    try:
        kR = readUIntBE[512](zR) + readUIntBE[512](pPrivateKeyR) mod TwoTwoFiftySix
    except DivByZeroError:
        doAssert(false, "Performing a modulus of 2^256 raised a DivByZeroError.")

    #Set the PrivateKey.
    var
        tempL: array[32, uint8] = kL.toByteArrayBE()
        tempR: array[64, uint8] = kR.toByteArrayBE()
        privateKey: EdPrivateKey
    for i in 0 ..< 32:
        privateKey.data[31 - i] = cuchar(tempL[i])
        privateKey.data[63 - i] = cuchar(tempR[i + 32])

    #Create the Public Key.
    var publicKey: EdPublicKey
    multiplyBase(addr publicKey.data[0], addr privateKey.data[0])

    try:
        result = HDWallet(
            #Set the Wallet fields.
            initiated: true,
            privateKey: privateKey,
            publicKey: publicKey,
            address: newAddress(publicKey),

            #Set the index and chain code.
            i: childArg,
            chainCode: chainCode
        )
        result.ffinalizeI()
        result.ffinalizeChainCode()
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when deriving a HDWallet: " & e.msg)

#Derive a full path.
proc derive*(
    wallet: HDWallet,
    path: seq[uint32]
): HDWallet {.forceCheck: [
    ValueError
].} =
    if path.len == 0:
        return wallet
    if path.len >= 2^20:
        raise newException(ValueError, "Derivation path depth is too big.")

    try:
        result = wallet.derive(path[0])
        for i in path[1 ..< path.len]:
                result = result.derive(i)
    except ValueError as e:
        fcRaise e

#Grab the next valid key on this path.
proc next*(
    wallet: HDWallet,
    path: seq[uint32] = @[],
    last: uint32 = 0
): HDWallet {.forceCheck: [
    ValueError
].} =
    if path.len >= 2^20 - 1:
        raise newException(ValueError, "Derivation path depth is too big.")

    var
        pathWallet: HDWallet
        i: uint32 = last + 1
    try:
        pathWallet = wallet.derive(path)
    except ValueError as e:
        fcRaise e

    while true:
        try:
            return pathWallet.derive(i)
        except ValueError:
            if i == high(uint32):
                raise newException(ValueError, "This path is out of keys.")
            continue
