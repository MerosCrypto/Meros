#HDWallet lib.
import ../src/Wallet/HDWallet

#String utils standard lib.
import strutils

#Wallet.
var wallet: HDWallet = newHDWallet()

#Print the info.
echo "Secret:"
echo wallet.secret.toHex()
echo "----"
echo "Address:"
echo wallet.address
