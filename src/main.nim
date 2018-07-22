discard """
#Number libs.
import BN
import lib/Base

#SHA512 lib.
import lib/SHA512 as SHA512File

#Block, blockchain, and State libs.
import Merit/Merit

#Wallet libs.
import Wallet/Wallet

import Lattice/Node

#Demo.
var wallet: Wallet = newWallet()
echo wallet.getPublicKey().verify("ffee", wallet.sign("ffee"))
"""

import lib/Argon2
import lib/SHA512

var
    a: string
    b: string
    c: string

a = Argon2(SHA512("ffee"), "a")
b = Argon2(SHA512("ffee"), "b")
c = Argon2(SHA512("ffff"), "b")

echo a
echo b
echo c
