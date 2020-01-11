#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Mint object.
import objects/MintObj
export MintObj

#Create a new Mint.
proc newMint*(
    hash: Hash[256],
    outputs: seq[MintOutput]
): Mint {.inline, forceCheck: [].} =
    newMintObj(hash, outputs)
