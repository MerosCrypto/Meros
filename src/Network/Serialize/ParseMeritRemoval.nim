#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Entry object and MeritRemoval object.
import ../../Database/Lattice/objects/EntryObj
import ../../Database/Lattice/objects/MeritRemovalObj

#Deserialize function.
import SerializeCommon
import SerializeMeritRemoval

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Parse a MeritRemoval.
proc parseMeritRemoval*(
    sendStr: string
): MeritRemoval {.raises: [
    ValueError,
    FinalAttributeError
].} =
    var
        #Public Key | Nonce | First | Second | Signature
        dataSeq: seq[string] = sendStr.deserialize(6)
        #Get the sender's Public Key.
        sender: EdPublicKey = newEdPublicKey(dataSeq[0].pad(32))
        #Get the sender's address.
        senderAddress: string = newAddress(sender)
        #Get the nonce.
        nonce: uint = uint(dataSeq[1].fromBinary())
        #Get the hash of the first Entry.
        first: Hash[512] = dataSeq[2].pad(64).toHash(512)
        #Get the hash of the second Entry.
        second: Hash[512] = dataSeq[3].pad(64).toHash(512)
        #Get the signature.
        signature: string = dataSeq[4].pad(64)

    #Create the MeritRemoval.
    result = newMeritRemovalObj(
        first,
        second
    )
    #Set the sender.
    result.sender = senderAddress
    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.hash = SHA512(result.serialize())

    #Set the signature.
    result.signature = signature
