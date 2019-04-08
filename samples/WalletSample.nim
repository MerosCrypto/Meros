#Wallet libs.
import ../src/Wallet/Wallet

#Wallet.
var wallet: Wallet = newWallet()

#Print the info.
echo "Seed:"
echo wallet.seed
echo "----"
echo "Address:"
echo wallet.address
