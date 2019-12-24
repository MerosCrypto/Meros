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
        assert(newBLSPrivateKey(wallet.privateKey.serialize()).serialize() == wallet.privateKey.serialize())
        assert($newBLSPrivateKey(wallet.privateKey.serialize()) == $wallet.privateKey)

    midFuzzTest "Recreating the Public Key.":
        assert(newBLSPublicKey(wallet.publicKey.serialize()).serialize() == wallet.publicKey.serialize())
        assert($newBLSPublicKey(wallet.publicKey.serialize()) == $wallet.publicKey)

    midFuzzTest "Reload the MinerWallet.":
        reloaded = newMinerWallet(wallet.privateKey.serialize())
        assert(wallet.privateKey.serialize() == reloaded.privateKey.serialize())
        assert(wallet.publicKey.serialize() == reloaded.publicKey.serialize())

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
        assert(wSig.serialize() == rSig.serialize())

        #Test recreating the signature.
        assert(newBLSSignature(wSig.serialize()).serialize() == wSig.serialize())

        #Verify the signature.
        assert(wSig.verify(newBLSAggregationInfo(wallet.publicKey, msg)))
