#BLS lib.
import ../src/lib/BLS

#Miner Wallet lib.
import ../src/Database/Merit/MinerWallet

#Create the Miner Wallet.
var miner: MinerWallet = newMinerWallet()

#Print the info.
echo "Private Key:"
echo miner.privateKey
echo "----"
echo "Public Key:"
echo miner.publicKey
