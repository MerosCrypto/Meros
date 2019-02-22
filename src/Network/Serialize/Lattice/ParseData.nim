#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet libraries.
import ../../../Wallet/Address
import ../../../Wallet/Wallet

#Entry object and Data object.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/DataObj

#Serialization functions.
import ../SerializeCommon
import SerializeData

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Parse a Data.
proc parseData*(
    sendStr: string
): Data {.raises: [
    ValueError,
    ArgonError,
    FinalAttributeError
].} =
    var
        #Public Key | Nonce | Data | Proof | Signature
        dataSeq: seq[string] = sendStr.deserialize(5)
        #Get the sender's Public Key.
        sender: EdPublicKey = newEdPublicKey(dataSeq[0].pad(32))
        #Get the sender's address.
        senderAddress: string = newAddress(sender)
        #Get the nonce.
        nonce: uint = uint(dataSeq[1].fromBinary())
        #Get the data.
        data: string = dataSeq[2]
        #Get the proof.
        proof: uint = uint(dataSeq[3].fromBinary())
        #Get the signature.
        signature: string = dataSeq[4].pad(64)

    #Create the Data.
    result = newDataObj(
        data
    )
    #Set the sender.
    result.sender = senderAddress
    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.hash = Blake512(result.serialize())
    #Set the proof.
    result.proof = proof
    #Set the Argon hash.
    result.argon = Argon(result.hash.toString(), proof.toBinary(), true)

    #Set the signature.
    result.signature = signature
