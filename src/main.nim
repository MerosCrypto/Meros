discard """
#Number libs.
import lib/BN
import lib/Base

#SHA512 lib.
import lib/SHA512 as SHA512File

#Block, blockchain, and State libs.
import DB/Merit/Merit

#Wallet libs.
import Wallet/Wallet

import DB/Lattice/Transaction

#Demo.
var
    wallet: Wallet = newWallet()
    hash: string = SHA512("test")
    sig: string = wallet.sign(hash)
    res: bool = wallet.getPublicKey().verify(hash, sig)

echo res
"""
#Wallet lib.
import Wallet/Wallet

#Declare the Wallet/Address vars here to not memory leak.
var
    wallet: Wallet
    address: string

#Run 500 times.
for _ in 0 ..< 500:
    #Create a new wallet.
    wallet = newWallet()
    #Get the address.
    address = wallet.getAddress()

    #Verify the address.
    if address.verify() == false:
        raise newException(Exception, "Invalid Address Type 1")
    #Verify the address for the matching pub key.
    if address.verify(wallet.getPublicKey()) == false:
        raise newException(Exception, "Invalid Address Type 2")

    #Print the generated address.
    echo address
