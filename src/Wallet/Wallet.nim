#Errors lib.
import ../lib/Errors

#HDWallet lib,.
import HDWallet
export HDWallet

#mnemonic lib.
import Mnemonic
export Mnemonic.Mnemonic

#Finals lib.
import finals

finalsd:
    type Wallet* = ref object
        mnemonic* {.final.}: Mnemonic
        hd* {.final.}: HDWallet

#Constructors.
proc newWallet*(): Wallet {.forceCheck: [].} =
    result = Wallet()
    try:
        result.mnemonic = newMnemonic()
        result.hd = newHDWallet(result.mnemonic.unlock()[0 ..< 32])
    except ValueError:
        result = newWallet()

proc newWallet*(
    password: string
): Wallet {.forceCheck: [].} =
    result = Wallet()
    try:
        result.mnemonic = newMnemonic()
        result.hd = newHDWallet(result.mnemonic.unlock(password)[0 ..< 32])
    except ValueError:
        result = newWallet(password)

proc newWallet*(
    sentence: string,
    password: string
): Wallet {.forceCheck: [
    ValueError
].} =
    result = Wallet()
    try:
        result.mnemonic = newMnemonic(sentence)
        result.hd = newHDWallet(result.mnemonic.unlock(password)[0 ..< 32])
    except ValueError as e:
        fcRaise e

#Converter.
converter toHDWallet*(
    wallet: Wallet
): HDWallet {.forceCheck: [].} =
    wallet.hd

#Getters.
proc privateKey*(
    wallet: Wallet
): EdPrivateKey {.forceCheck: [].} =
    wallet.hd.privateKey

proc publicKey*(
    wallet: Wallet
): EdPublicKey {.forceCheck: [].} =
    wallet.hd.publicKey

proc address*(
    wallet: Wallet
): string {.forceCheck: [].} =
    wallet.hd.address
