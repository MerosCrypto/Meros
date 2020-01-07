#MinerWallet Test.

#Test lib.
import unittest2

#Fuzzing lib.
import ../Fuzzed

#Util lib.
import ../../src/lib/Util

#MinerWallet lib.
import ../../src/Wallet/MinerWallet

#Random standard lib.
import random

#PrivateKey random.
randomize(int64(getTime()))

suite "MinerWaller":
    setup:
        var
            #MinerWallets.
            wallet: MinerWallet = newMinerWallet()
            reloaded: MinerWallet = newMinerWallet(wallet.privateKey.serialize())

    midFuzzTest "Recreating the Private Key.":
        check(newBLSPrivateKey(wallet.privateKey.serialize()).serialize() == wallet.privateKey.serialize())
        check($newBLSPrivateKey(wallet.privateKey.serialize()) == $wallet.privateKey)

    midFuzzTest "Recreating the Public Key.":
        check(newBLSPublicKey(wallet.publicKey.serialize()).serialize() == wallet.publicKey.serialize())
        check($newBLSPublicKey(wallet.publicKey.serialize()) == $wallet.publicKey)

    midFuzzTest "Reload the MinerWallet.":
        reloaded = newMinerWallet(wallet.privateKey.serialize())
        check(wallet.privateKey.serialize() == reloaded.privateKey.serialize())
        check(wallet.publicKey.serialize() == reloaded.publicKey.serialize())

    midFuzzTest "Messages.":
        var
            msg: string
            wSig: BLSSignature
            rSig: BLSSignature

        for _ in 0 ..< rand(100):
            msg &= char(rand(255))

        #Sign the messages.
        wSig = wallet.sign(msg)
        rSig = reloaded.sign(msg)

        #Verify they're the same signature..
        check(wSig.serialize() == rSig.serialize())

        #Test recreating the signature.
        check(newBLSSignature(wSig.serialize()).serialize() == wSig.serialize())

        #Verify the signature.
        check(wSig.verify(newBLSAggregationInfo(wallet.publicKey, msg)))
