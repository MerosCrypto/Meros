#Address Test.

#Address/Wallet libs.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

#String utils standard lib.
import strutils

#Wallet.
var wallet: Wallet

#Run 100 times.
for i in 1 .. 100:
    echo "Testing Address creation, iteration " & $i & "."

    #Create a new wallet.
    wallet = newWallet()

    #Verify the address.
    assert(
        Address.isValid(wallet.address),
        "Invalid Address."
    )

    #Verify the address for the matching pub key.
    assert(
        Address.isValid(
            wallet.address,
            wallet.publicKey
        ),
        "Address doesn't match the Public Key."
    )

    #Verify toPublicKey works.
    assert(wallet.publicKey.toString() == Address.toPublicKey(wallet.address), "Address.toPublicKey() didn't return the correct Public Key.")

echo "Finished the Wallet/Address Test."
