#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Wallet libraries.
import ../../../Wallet/Address
import ../../../Wallet/Wallet

#Entry object and Claim lib.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/Claim

#Serialize common functions.
import ../SerializeCommon

#Finals lib.
import finals

#Parse a Claim.
proc parseClaim*(
    claimStr: string
): Claim {.raises: [
    ValueError,
    BLSError,
    FinalAttributeError
].} =
    var
        #Public Key | Nonce | Mint Nonce | BLS Signature | Signature
        claimSeq: seq[string] = claimStr.deserialize(
            PUBLIC_KEY_LEN,
            INT_LEN,
            INT_LEN,
            BLS_SIGNATURE_LEN,
            SIGNATURE_LEN
        )
        #Get the sender's Public Key.
        sender: EdPublicKey = newEdPublicKey(claimSeq[0])
        #Get the nonce.
        nonce: uint = uint(claimSeq[1].fromBinary())
        #Get the mint nonce.
        mintNonce: uint = uint(claimSeq[2].fromBinary())
        #Get the BLS signature.
        bls: BLSSignature = newBLSSignature(claimSeq[3])
        #Get the signature.
        signature: string = claimSeq[4]

    #Create the Claim.
    result = newClaim(
        mintNonce,
        nonce
    )

    #Set the sender.
    result.sender = newAddress(sender)

    #Set the BLS signature.
    result.bls = bls

    #Set the hash.
    result.hash = Blake384(claimSeq.reserialize(1, 3))

    #Set the signature.
    result.signature = signature
