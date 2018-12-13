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

#Entry, and Claim object.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/Claim

#Serialize/Deserialize functions.
import ../SerializeCommon
import SerializeClaim

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Parse a Claim.
proc parseClaim*(
    claimStr: string
): Claim {.raises: [
    ValueError,
    BLSError,
    FinalAttributeError
].} =
    var
        #Public Key | Nonce | Mint Nonce | BLS | Signature
        claimSeq: seq[string] = claimStr.deserialize(5)
        #Get the sender's Public Key.
        sender: EdPublicKey = newEdPublicKey(claimSeq[0].pad(32))
        #Get the nonce.
        nonce: uint = uint(claimSeq[1].fromBinary())
        #Get the mint nonce.
        mintNonce: uint = uint(claimSeq[2].fromBinary())
        #Get the BLS signature.
        bls: BLSSignature = newBLSSignature(claimSeq[3].pad(96))
        #Get the signature.
        signature: string = claimSeq[4].pad(64)

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
    result.hash = SHA512(result.serialize())

    #Set the signature.
    result.signature = signature
