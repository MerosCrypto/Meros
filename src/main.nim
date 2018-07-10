#Number libs.
import lib/BN
import lib/Hex
import lib/Base58

#Hash libs.
import lib/SHA512 as SHA512File
import lib/Lyra2

#Time lib.
import lib/time as TimeFile

#Block, blockchain, and State libs.
import Reputation/Reputation

#Wallet files.
import Wallet/Wallet

#Demo.
var wallet: Wallet = newWallet()
echo wallet.getPublicKey().verify("ffee", wallet.sign("ffee"))
