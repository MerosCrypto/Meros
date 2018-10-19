#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Hash lib.
import ../../lib/Hash

#Entry object and Data object.
import ../../Database/Lattice/objects/EntryObj
import ../../Database/Lattice/objects/DataObj

#Deserialize function.
import SerializeCommon

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
    SodiumError,
    FinalAttributeError
].} =
    var
        #Public Key | Nonce | Data | Proof | Signature
        dataSeq: seq[string] = sendStr.deserialize(6)
        #Get the sender's Public Key.
        sender: EdPublicKey = newEdPublicKey(dataSeq[0].pad(32, char(0)))
        #Get the sender's address.
        senderAddress: string = newAddress(sender)
        #Get the nonce.
        nonce: uint = uint(dataSeq[1].fromBinary())
        #Get the data.
        data: string = dataSeq[2]
        #Get the proof.
        proof: string = dataSeq[3]
        #Get the signature.
        signature: string = dataSeq[4].pad(64, char(0))

    #Create the Data.
    result = newDataObj(
        data
    )
    #Set the sender.
    result.sender = senderAddress
    #Set the nonce.
    result.nonce = nonce
    #Set the SHA512 hash.
    result.sha512 = SHA512(data)
    #Set the proof.
    result.proof = uint(proof.fromBinary())
    #Set the hash.
    result.hash = Argon(result.sha512.toString(), proof, true)

    #Verify the signature.
    if not sender.verify(result.hash.toString(), signature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature = signature
