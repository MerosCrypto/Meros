#Wallet Test.

#Util lib.
import ../../src/lib/Util

#Wallet libs.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

#Random standard lib.
import random

#Seed random.
randomize(getTime())

var
    #Wallets.
    wallet: Wallet
    reloaded: Wallet
    #Message.
    msg: string
    #Signatures.
    wSig: EdSignature
    rSig: EdSignature

echo "Testing Wallet functionality."

#Run 100 times.
for _ in 1 .. 100:
    #Create a new wallet.
    wallet = newWallet()

    #Test recreating the Seed.
    assert(newEdSeed(wallet.seed.toString()).toString() == wallet.seed.toString())
    assert($newEdSeed($wallet.seed) == $wallet.seed)

    #Test recreating the Public Key.
    assert(newEdPublicKey(wallet.publicKey.toString()).toString() == wallet.publicKey.toString())
    assert($newEdPublicKey($wallet.publicKey) == $wallet.publicKey)

    #Reload the Wallet.
    reloaded = newWallet(wallet.seed)
    assert(wallet.seed.toString() == reloaded.seed.toString())
    assert(wallet.publicKey.toString() == reloaded.publicKey.toString())
    reloaded = newWallet(wallet.seed, wallet.address)
    assert(wallet.seed.toString() == reloaded.seed.toString())
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
        assert(newEdSignature(wSig.toString()).toString() == wSig.toString())
        assert($newEdSignature($wSig) == $wSig)

        #Verify the signature.
        assert(wallet.verify(msg, wSig))
        assert(wallet.publicKey.verify(msg, wSig))
        assert(reloaded.verify(msg, wSig))
        assert(reloaded.publicKey.verify(msg, wSig))

echo "Finished the Wallet/Wallet Test."
