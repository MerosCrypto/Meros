#Wallet lib.
import ../src/Wallet/Wallet

#SetOnce lib.
import SetOnce

#Declare the Wallet/Address vars here to not memory leak.
var wallet: Wallet

#Run 500 times.
for _ in 0 ..< 500:
    #Create a new wallet.
    wallet = newWallet()

    #Verify the address.
    if not wallet.address.verify():
        raise newException(Exception, "Invalid Address Type 1")
    #Verify the address for the matching pub key.
    if not wallet.address.verify(wallet.publicKey.toValue()):
        raise newException(Exception, "Invalid Address Type 2")

    #Print the generated address.
    echo wallet.address.toValue()
