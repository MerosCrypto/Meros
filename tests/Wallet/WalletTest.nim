#Test lib.
import unittest2

#Util lib.
import ../../src/lib/Util

#Wallet libs.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

#Random standard lib.
import random

proc verify(
    wallet: Wallet
) =
    #Test recreating the Public Key.
    assert(newEdPublicKey(wallet.publicKey.toString()).toString() ==
        wallet.publicKey.toString())
    assert($newEdPublicKey($wallet.publicKey) == $wallet.publicKey)

    #Create messages.
    var
        msg: string
        sig: EdSignature
    for m in 1 .. rand(100):
        msg = ""
        for _ in 0 ..< m:
            msg &= char(rand(255))

        #Sign the message.
        sig = wallet.sign(msg)

        #Verify the signature.
        assert(wallet.verify(msg, sig))

suite "Wallet":
    setup:
        randomize(int64(getTime()))

    test "New wallet without password.":
        verify(newWallet(""))

    test "New wallet with password.":
        verify(newWallet("password"))

    test "Reload wallet.":
        var
            wallet = newWallet("password")
            reloaded = newWallet(wallet.mnemonic.sentence, "password")

        assert(wallet.mnemonic.entropy == reloaded.mnemonic.entropy)
        assert(wallet.mnemonic.checksum == reloaded.mnemonic.checksum)
        assert(wallet.mnemonic.sentence == reloaded.mnemonic.sentence)

        assert(wallet.hd.chainCode == reloaded.hd.chainCode)
        assert(wallet.hd.privateKey == reloaded.hd.privateKey)
        assert(wallet.hd.publicKey == reloaded.hd.publicKey)
        assert(wallet.hd.address == reloaded.hd.address)
