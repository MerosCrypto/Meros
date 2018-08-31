#Address Test.

#Base library.
import ../../src/lib/Base

#Address/Wallet libraries.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

#Test a couple of addresses.
assert(
    Address.verify("Emb123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz") == false, #Every Base58 char with no checksum.
    "Address.verify returned true with no prefix/an invalid checksum."
)

#Define a wallet and address outside of the loop to prevent memory leaks.
var
    wallet: Wallet
    address: string
#Run 10 times.
for _ in 0 ..< 10:
    #Create a new wallet.
    wallet = newWallet()
    #Get the address.
    address = wallet.getAddress()

    #Verify the address.
    assert(
        Address.verify(address),
        "Invalid Address."
    )

    #Verify the address for the matching pub key.
    assert(
        Address.verify(
            address,
            wallet.getPublicKey()
        ),
        "Address doesn't match the Public Key."
    )

    #Verify toBN works.
    assert($(wallet.getPublicKey()) == Address.toBN(address).toString(16), "Address.toBN didn't return the correct BN.")

echo "Finished the Wallet/Address test."
