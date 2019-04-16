#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet lib.
import ../../Wallet/Wallet

#Entry object.
import objects/EntryObj

#Mint object.
import objects/MintObj
export MintObj

#Import the Serialization library.
import ../../Network/Serialize/Lattice/SerializeMint

#BN lib.
import BN

#Create a new Mint.
proc newMint*(
    output: string,
    amount: BN,
    nonce: Natural
): Mint {.forceCheck: [
    ValueError
].} =
    #Verify the amount.
    if amount <= newBN(0):
        raise newException(ValueError, "Mint amount is negative or zero.")

    #Create the result.
    result = newMintObj(
        output,
        amount
    )

    try:
        #Set the nonce.
        result.nonce = nonce
        #Set the hash.
        result.hash = Blake384(result.serialize())
    except ValueError as e:
        raise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Mint: " & e.msg)
