#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Numerical libs.
import BN
import ../../lib/Base

#Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Hash lib.
import ../../lib/Hash

#Node object and Send object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/SendObj

#Serialize/Deserialize functions.
import SerializeCommon
import SerializeSend

#SetOnce lib.
import SetOnce

#String utils standard lib.
import strutils

#Parse a Send.
proc parseSend*(sendStr: string): Send {.raises: [ResultError, ValueError, Exception].} =
    var
        #Public Key | Nonce | Output | Amount | Proof | Signature
        sendSeq: seq[string] = sendStr.deserialize(6)
        #Get the sender's public key.
        sender: PublicKey = newPublicKey(sendSeq[0].toHex())
        #Set the input address based off the sender's public key.
        input: string = sender.newAddress()
        #Get the nonce.
        nonce: BN = sendSeq[1].toBN(256)
        #Get the output.
        output: string = newAddress(sendSeq[2].toHex())
        #Get the amount.
        amount: BN = sendSeq[3].toBN(256)
        #Get the proof.
        proof: string = sendSeq[4]
        #Get the signature.
        signature: string = sendSeq[5].toHex().pad(128)

    #Create the Send.
    result = newSendObj(
        output,
        amount
    )

    #Set the sender.
    result.sender.value = input
    #Set the nonce.
    result.nonce.value = nonce
    #Set the SHA512 hash.
    result.sha512.value = SHA512(result.serialize())
    #Set the proof.
    result.proof.value = proof.toBN(256)
    #Set the hash.
    result.hash.value = Argon(result.sha512.toString(), proof, true)

    #Verify the signature.
    if not sender.verify($result.hash.toValue(), signature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature.value = signature
