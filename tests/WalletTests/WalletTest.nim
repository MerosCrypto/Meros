#Wallet Test.

#Util lib.
import ../../src/lib/Util

#Wallet libs.
import ../../src/Wallet/Address
import ../../src/Wallet/HDWallet

#Random standard lib.
import random

#Seed random.
randomize(getTime())

var
    #Wallet.
    wallet: Wallet
    #Message.
    msg: string
    #Signature.
    sig: EdSignature

#Run 255 times.
for _ in 1 .. 255:
    #Create a new wallet.
    wallet = newHDWallet().next()

    #Test recreating the Public Key.
    assert(newEdPublicKey(wallet.publicKey.toString()).toString() == wallet.publicKey.toString())
    assert($newEdPublicKey($wallet.publicKey) == $wallet.publicKey)

    #Create messages.
    for m in 1 .. 255:
        msg = ""
        for _ in 0 ..< m:
            msg &= char(rand(255))

        #Sign the message.
        sig = wallet.sign(msg)

        #Verify the signature.
        assert(wallet.verify(msg, sig))

echo "Finished the Wallet/Wallet Test."
