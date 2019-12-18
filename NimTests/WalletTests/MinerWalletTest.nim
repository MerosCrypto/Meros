#MinerWallet Test.

#Util lib.
import ../../src/lib/Util

#MinerWallet lib.
import ../../src/Wallet/MinerWallet

#Random standard lib.
import random

#PrivateKey random.
randomize(int64(getTime()))

proc test*() =
    var
        #MinerWallets.
        wallet: MinerWallet
        reloaded: MinerWallet
        #Message.
        msg: string
        #Signatures.
        wSig: BLSSignature
        rSig: BLSSignature

    #Run 100 times.
    for _ in 1 .. 100:
        #Create a new wallet.
        wallet = newMinerWallet()

        #Test recreating the Private Key.
        assert(newBLSPrivateKey(wallet.privateKey.serialize()).serialize() == wallet.privateKey.serialize())
        assert($newBLSPrivateKey(wallet.privateKey.serialize()) == $wallet.privateKey)

        #Test recreating the Public Key.
        assert(newBLSPublicKey(wallet.publicKey.serialize()).serialize() == wallet.publicKey.serialize())
        assert($newBLSPublicKey(wallet.publicKey.serialize()) == $wallet.publicKey)

        #Reload the MinerWallet.
        reloaded = newMinerWallet(wallet.privateKey.serialize())
        assert(wallet.privateKey.serialize() == reloaded.privateKey.serialize())
        assert(wallet.publicKey.serialize() == reloaded.publicKey.serialize())

        #Create messages.
        for m in 1 .. 100:
            msg = ""
            for _ in 0 ..< m:
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

    echo "Finished the Wallet/MinerWallet Test."
