#BLS and Miner Wallet libs.
import ../src/lib/BLS
import ../src/Wallet/MinerWallet

#Create the Miner Wallet.
var miner: MinerWallet = newMinerWallet()

#Print the info.
echo "Private Key:"
echo miner.privateKey
echo "----"
echo "Public Key:"
echo miner.publicKey
