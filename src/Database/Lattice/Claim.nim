#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Wallet libs.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Entry object.
import objects/EntryObj

#Claim object.
import objects/ClaimObj
export ClaimObj

#Import the Serialization library.
import ../../Network/Serialize/Lattice/SerializeClaim

#Create a new Claim Entry.
func newClaim*(
    mintNonce: Natural,
    nonce: Natural
): Claim {.forceCheck: [].} =
    #Create the result.
    result = newClaimObj(mintNonce)

    #Set the nonce.
    try:
        result.nonce = nonce
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Claim: " & e.msg)

proc sign*(
    claim: Claim,
    miner: MinerWallet,
    wallet: Wallet
) {.forceCheck: [
    AddressError,
    BLSError,
    SodiumError
].} =
    try:
        #Set the sender behind the Entry.
        claim.sender = wallet.address

        #Sign MintNonce & PublicKey.
        claim.bls = miner.sign(claim.mintNonce.toBinary() & Address.toPublicKey(claim.sender))

        #Set the hash.
        claim.hash = Blake384(claim.serialize())

        #Sign the hash of the Claim.
        claim.signature = wallet.sign(claim.hash.toString())
        claim.signed = true
    except AddressError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e
    except SodiumError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Claim: " & e.msg)
