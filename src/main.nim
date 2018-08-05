#Number libs.
import lib/BN
import lib/Base

#SHA512 lib.
import lib/SHA512 as SHA512File

#Block, blockchain, and State libs.
import Merit/Merit

#Wallet libs.
import Wallet/Wallet

import Lattice/Transaction

#Demo.
var wallet: Wallet = newWallet()
echo wallet.getPublicKey().verify("ffee", wallet.sign("ffee"))
