#MinerWallet lib.
import ../src/Wallet/MinerWallet

#String utils standard lib.
import strutils

#Create the Miner Wallet.
var miner: MinerWallet = newMinerWallet()

#Print the info.
echo "Private Key: ", miner.privateKey
echo "----"
echo "Public Key: ", miner.publicKey
