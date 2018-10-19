#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Hash lib.
import ../../lib/Hash

#Index, Entry, and Receive object.
import ../../Database/Lattice/objects/IndexObj
import ../../Database/Lattice/objects/EntryObj
import ../../Database/Lattice/objects/ReceiveObj

#Serialize/Deserialize functions.
import SerializeCommon
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
        #Public Key | Nonce | Input Address | Input Nonce | Signature
        recvSeq: seq[string] = recvStr.deserialize(5)
        #Get the sender's Public Key.
        sender: EdPublicKey = newEdPublicKey(recvSeq[0].pad(32, char(0)))
        #Get the nonce.
        nonce: uint = uint(recvSeq[1].fromBinary())
        #Get the input Address.
        inputAddress: string = recvSeq[2]
        #Get the input nonce.
        inputNonce: uint = uint(recvSeq[3].fromBinary())
        #Get the signature.
        signature: string = recvSeq[4].pad(64, char(0))

    #Parse Receives from the minter properly.
    if inputAddress == "":
        inputAddress = "minter"
    else:
        inputAddress = newAddress(inputAddress)

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
    result.hash = SHA512(result.serialize())

    #Verify the signature.
    if not sender.verify(result.hash.toString(), signature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature = signature
