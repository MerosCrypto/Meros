#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet libraries.
import ../../../Wallet/Address
import ../../../Wallet/Wallet

#Index, Entry, and Receive object.
import ../../../Database/common/objects/IndexObj
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/ReceiveObj

#Serialize/Deserialize functions.
import ../SerializeCommon
import SerializeReceive

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Parse a Receive.
proc parseReceive*(
    recvStr: string
): Receive {.raises: [
    ValueError,
    SodiumError,
    FinalAttributeError
].} =
    var
        #Public Key | Nonce | Input Key | Input Nonce | Signature
        recvSeq: seq[string] = recvStr.deserialize(5)
        #Get the sender's Public Key.
        sender: EdPublicKey = newEdPublicKey(recvSeq[0].pad(32))
        #Get the nonce.
        nonce: uint = uint(recvSeq[1].fromBinary())
        #Get the Input Address.
        inputAddress: string = newAddress(recvSeq[2].pad(32))
        #Get the input nonce.
        inputNonce: uint = uint(recvSeq[3].fromBinary())
        #Get the signature.
        signature: string = recvSeq[4].pad(64)

    #Create the Receive.
    result = newReceiveObj(
        newIndex(
            inputAddress,
            inputNonce
        )
    )

    #Set the sender.
    result.sender = newAddress(sender)
    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.hash = Blake512(result.serialize())

    #Verify the signature.
    if not sender.verify(result.hash.toString(), signature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature = signature
