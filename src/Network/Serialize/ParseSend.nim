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

#delim character/serialize function.
import SerializeCommon
import SerializeSend

#String utils standard lib.
import strutils

#Parse a send.
proc parseSend*(sendStr: string): Send {.raises: [ResultError, ValueError, Exception].} =
    var
        #Public Key | Nonce | Output | Amount | Proof | Signature
        sendSeq: seq[string] = sendStr.toBN(253).toString(256).split(delim)
        #Get the sender's public key.
        sender: PublicKey = sendSeq[0].toBN(255).toString(16).newPublicKey()
        #Set the input address based off the sender's public key.
        input: string = sender.newAddress()
        #Get the nonce.
        nonce: BN = sendSeq[1].toBN(255)
        #Get the output.
        output: string = newAddress(sendSeq[2].toBN(255).toString(16))
        #Get the amount.
        amount: BN = sendSeq[3].toBN(255)
        #Get the proof.
        proof: string = sendSeq[4].toBN(255).toString(16)
        #Get the signature.
        signature: string = sendSeq[5].toBN(255).toString(16).pad(128)

    #Create the Send.
    result = newSendObj(
        output,
        amount
    )

    #Set the nonce.
    if not result.setNonce(nonce):
        raise newException(ValueError, "Couldn't set the Node's nonce.")

    #Set the SHA512 hash.
    if not result.setSHA512(SHA512(result.serialize())):
        raise newException(ValueError, "Couldn't set the Send SHA512.")

    #Set the hash.
    if not result.setHash(Argon(result.getSHA512().toString(), proof, true)):
        raise newException(ValueError, "Couldn't set the Node's hash.")

    #Verify the signature.
    if not sender.verify($result.getHash(), signature):
        raise newException(ValueError, "Received signature was invalid.")

    #Set the proof.
    if not result.setProof(proof.toBN(16)):
        raise newException(ValueError, "Couldn't set the Send's proof.")

    #Set the sender.
    if not result.setSender(input):
        raise newException(ValueError, "Couldn't set the Node's sender.")

    #Set the signature.
    if not result.setSignature(signature):
        raise newException(ValueError, "Couldn't set the Node's signature.")
