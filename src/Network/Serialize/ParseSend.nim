#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Entry object and Send object.
import ../../Database/Lattice/objects/EntryObj
import ../../Database/Lattice/objects/SendObj

#Serialize/Deserialize functions.
import SerializeCommon
import SerializeSend

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Parse a Send.
proc parseSend*(
    sendStr: string
): Send {.raises: [
    ValueError,
    ArgonError,
    FinalAttributeError
].} =
    var
        #Public Key | Nonce | Output | Amount | Proof | Signature
        sendSeq: seq[string] = sendStr.deserialize(6)
        #Get the sender's public key.
        sender: EdPublicKey = newEdPublicKey(sendSeq[0].pad(32))
        #Set the input address based off the sender's public key.
        input: string = newAddress(sender)
        #Get the nonce.
        nonce: uint = uint(sendSeq[1].fromBinary())
        #Get the output.
        output: string = newAddress(sendSeq[2].pad(32))
        #Get the amount.
        amount: BN = sendSeq[3].toBN(256)
        #Get the proof.
        proof: string = sendSeq[4]
        #Get the signature.
        signature: string = sendSeq[5].pad(64)

    #Create the Send.
    result = newSendObj(
        output,
        amount
    )

    #Set the sender.
    result.sender = input
    #Set the nonce.
    result.nonce = nonce
    #Set the SHA512 hash.
    result.sha512 = SHA512(result.serialize())
    #Set the proof.
    result.proof = uint(proof.fromBinary())
    #Set the hash.
    result.hash = Argon(result.sha512.toString(), proof, true)

    #Set the signature.
    result.signature = signature
