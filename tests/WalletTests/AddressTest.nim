#Address Test.

#Base library.
import ../../src/lib/Base

#Address/Wallet libraries.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

#SetOnce lib.
import SetOnce

#Test a couple of addresses.
assert(
    not Address.verify("Emb123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"), #Every Base58 char with no checksum.
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

    #Verify the address.
    assert(
        Address.verify(wallet.address),
        "Invalid Address."
    )

    #Verify the address for the matching pub key.
    assert(
        Address.verify(
            wallet.address.toValue(),
            wallet.publicKey.toValue()
        ),
        "Address doesn't match the Public Key."
    )

    #Verify toBN works.
    assert($wallet.publicKey.toValue() == Address.toBN(wallet.address).toString(16), "Address.toBN didn't return the correct BN.")

echo "Finished the Wallet/Address test."
