#Address Test.

#Wallet libs.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

proc test*() =
    #Wallet.
    var wallet: Wallet = newWallet("")

    #Run 100 times.
    for i in 1 .. 100:
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
