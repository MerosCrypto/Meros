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
    wallet: HDWallet
    #Message.
    msg: string
    #Signature.
    sig: EdSignature

var pub = newEdPublicKey("45551CFD22CE4C960E5C0C5E7424D3E9CDDBA5CE3DAA22663556147FEBD27AB4")
sig = newEdSignature("7cf05c4cddcd46f9dc9de4db73a1ea7ec43c267384988c016c8d51e155ded73d24632c6db8a548bbfbcffc9beb44a140a1ecc3fc8f3af41e5c56eaa3f97ed90e")
echo pub.verify("hello world", sig)

#Run 100 times.
for _ in 1 .. 100:
    #Create a new wallet.
    wallet = newHDWallet().next()
    echo wallet.privateKey
    echo wallet.publicKey

    #Test recreating the Public Key.
    assert(newEdPublicKey(wallet.publicKey.toString()).toString() == wallet.publicKey.toString())
    assert($newEdPublicKey($wallet.publicKey) == $wallet.publicKey)

    #Create messages.
    for m in 1 .. 100:
        msg = ""
        for _ in 0 ..< m:
            msg &= char(rand(255))

        #Sign the message.
        sig = wallet.sign(msg)

        #Verify the signature.
        assert(wallet.verify(msg, sig))

echo "Finished the Wallet/Wallet Test."
