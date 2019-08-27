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
        assert(newBLSPrivateKeyFromBytes(wallet.privateKey.toString()).toString() == wallet.privateKey.toString())
        assert($newBLSPrivateKeyFromBytes($wallet.privateKey) == $wallet.privateKey)

        #Test recreating the Public Key.
        assert(newBLSPublicKey(wallet.publicKey.toString()).toString() == wallet.publicKey.toString())
        assert($newBLSPublicKey($wallet.publicKey) == $wallet.publicKey)

        #Reload the MinerWallet.
        reloaded = newMinerWallet(wallet.seed)
        assert(wallet.privateKey.toString() == reloaded.privateKey.toString())
        assert(wallet.publicKey.toString() == reloaded.publicKey.toString())

        #Create messages.
        for m in 1 .. 100:
            msg = ""
            for _ in 0 ..< m:
                msg &= char(rand(255))

            #Sign the messages.
            wSig = wallet.sign(msg)
            rSig = reloaded.sign(msg)

            #Verify they're the same signature..
            assert(wSig.toString() == rSig.toString())

            #Test recreating the signatures.
            assert(newBLSSignature(wSig.toString()).toString() == wSig.toString())
            assert($newBLSSignature($wSig) == $wSig)

            #Verify the signature.
            wSig.setAggregationInfo(
                newBLSAggregationInfo(
                    wallet.publicKey,
                    msg
                )
            )
            assert(wSig.verify())

    echo "Finished the Wallet/MinerWallet Test."
