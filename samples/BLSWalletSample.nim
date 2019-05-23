#MinerWallet lib.
import ../src/Wallet/MinerWallet

#Create the Miner Wallet.
var miner: MinerWallet = newMinerWallet()

#Print the info.
echo "Seed: ", miner.seed
echo "----"
echo "Public Key: ", miner.publicKey
