#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Base lib.
import ../../lib/Base

#BLS/MinerWallet libs.
import ../../lib/BLS
import ../../Wallet/MinerWallet

#Wallet libs.
import ../../Wallet/Address
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

    #Sign MintNonce & PublicKey.
    claim.bls = miner.sign(claim.mintNonce.toBinary() & Address.toBN(claim.sender).toString(256))

    #Set the hash.
    claim.hash = Blake512(claim.serialize())

    #Sign the hash of the Claim.
    claim.signature = wallet.sign(claim.hash.toString())
