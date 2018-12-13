#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#BN lib.
import BN

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet
import ../../Wallet/Address

#Import the Serialization library.
import ../../Network/Serialize/Lattice/SerializeMint

#Entry object.
import objects/EntryObj

#Mint object.
import objects/MintObj
export MintObj

#Finals lib.
import finals

#Used to handle data strings.
import strutils

#Create a new Mint.
proc newMint*(
    output: string,
    amount: BN,
    nonce: uint
): Mint {.raises: [ValueError, FinalAttributeError].} =
    #Verify the amount.
    if amount <= newBN(0):
        raise newException(ValueError, "Mint amount is negative or zero.")

    #Craft the result.
    result = newMintObj(
        output,
        amount
    )

    #Set the nonce.
    result.nonce = nonce

    #Set the hash.
    result.hash = SHA512(result.serialize())
