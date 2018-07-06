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
import Reputation/Block
import Reputation/Blockchain
import Reputation/State

#Wallet files.
import Wallet/PublicKey
import Wallet/Address
import Wallet/Wallet

#Demo.
var wallet: Wallet = newWallet()
echo wallet.verify("ffee", wallet.sign("ffee"))
