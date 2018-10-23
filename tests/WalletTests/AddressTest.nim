#Address Test.

#Base library.
import ../../src/lib/Base

#Address/Wallet libraries.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

#String utils standard lib.
import strutils

#Function to strip leading 0 bytes since Public Keys have them but BNs don't.
proc strip(str: string): string =
    result = str
    while result[0 .. 1] == "00":
        result = result[2 .. result.len - 1]

#Define a wallet and address outside of the loop to prevent memory leaks.
var
    wallet: Wallet
    address: string
#Run 20 times.
for i in 1 .. 20:
    echo "Testing Address creation, iteration " & $i & "."

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
            wallet.address,
            wallet.publicKey
        ),
        "Address doesn't match the Public Key."
    )

    #Verify toBN works.
    assert(strip($wallet.publicKey) == Address.toBN(wallet.address).toString(16), "Address.toBN didn't return the correct BN.")

echo "Finished the Wallet/Address test."
