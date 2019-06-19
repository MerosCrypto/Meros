#Address Test.

#Wallet libs.
import ../../src/Wallet/Address
import ../../src/Wallet/HDWallet

var
    #HDWallet.
    hd: HDWallet = newHDWallet()
    #Wallet.
    wallet: HDWallet

#Run 100 times.
for i in 1 .. 100:
    #Derive a Wallet.
    wallet = hd.next()

    #Verify the address.
    assert(Address.isValid(wallet.address))

    #Verify the address for the matching pub key.
    assert(
        Address.isValid(
            wallet.address,
            wallet.publicKey
        )
    )

    #Verify toPublicKey works.
    assert(wallet.publicKey.toString() == Address.toPublicKey(wallet.address))

echo "Finished the Wallet/Address Test."
