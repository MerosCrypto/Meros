#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#BLS/MinerWallet libs.
import ../../lib/BLS
import ../Merit/MinerWallet

#Wallet libs.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/Lattice/SerializeClaim

#Entry object.
import objects/EntryObj

#Claim object.
import objects/ClaimObj
export ClaimObj

#Finals lib.
import finals

#Create a new Claim Entry.
proc newClaim*(
    mintNonce: uint,
    nonce: uint
): Claim {.raises: [FinalAttributeError].} =
    #Craft the result.
    result = newClaimObj(mintNonce)

    #Set the nonce.
    result.nonce = nonce

proc sign*(
    claim: Claim,
    miner: MinerWallet,
    wallet: Wallet
) {.raises: [
    ValueError,
    SodiumError,
    FinalAttributeError
].} =
    #Set the sender behind the Entry.
    claim.sender = wallet.address

    #Sign MintNonce & "." & EMBAddress
    claim.bls = miner.sign($claim.mintNonce & "." & claim.sender)

    #Set the hash.
    claim.hash = SHA512(claim.serialize())

    #Sign the hash of the Claim.
    claim.signature = wallet.sign(claim.hash.toString())
