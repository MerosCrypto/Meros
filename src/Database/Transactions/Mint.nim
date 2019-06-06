#Errors lib.
import ../../lib/Errors

#Transaction lib.
import Transaction

#Mint object.
import objects/MintObj
export MintObj

#Create a new Mint.
func newMint*(
    nonce: int,
    key: BLSPublicKey,
    amount: uint64
): Mint {.forceCheck: [
    ValueError
].} =
    #Create the result.
    result = newMintObj(
        nonce,
        key,
        amount
    )

    #Hash it.
    discard result.hash
