#MinerWallet lib.
import ../src/Wallet/MinerWallet

#Create the Miner Wallet.
var miner: MinerWallet = newMinerWallet()

#Print the info.
echo "Private Key: ", miner.privateKey
echo "----"
echo "Public Key: ", miner.publicKey
