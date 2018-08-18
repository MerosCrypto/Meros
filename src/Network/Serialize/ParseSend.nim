#Errors lib.
import ../../lib/Errors

#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Hashing libs.
import ../../lib/SHA512
import ../../lib/Argon

#Node object and send object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/SendObj

#delim character/serialize function.
import common
import SerializeSend

#String utils standard lib.
import strutils

#Parse a send.
proc parse*(sendStr: string): Send {.raises: [ResultError, ValueError, Exception].} =
    var
        #Public Key | Nonce | Output | Amount | Proof | Signature
        sendSeq: seq[string] = sendStr.split(delim)
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
        signature: string = sendSeq[5].toBN(255).toString(16)

    #Create the send.
    result = newSendObj(
        output,
        amount
    )

    #Set the descendant type.
    if not result.setDescendant(1):
        raise newException(ValueError, "Couldn't set the Node's descendant type.")

    #Set the nonce.
    if not result.setNonce(nonce):
        raise newException(ValueError, "Couldn't set the Node's nonce.")

    #Set the SHA512 hash.
    if not result.setSHA512(SHA512(result.serialize())):
        raise newException(ValueError, "Couldn't set the Send SHA512.")

    #Set the hash.
    if result.setHash(Argon(result.getSHA512(), proof, true)) == false:
        raise newException(ValueError, "Couldn't set the Node's hash.")

    #Verify the signature.
    if sender.verify(result.getHash(), signature) == false:
        raise newException(ValueError, "Received signature was invalid.")

    #Set the proof.
    if result.setProof(proof.toBN(16)) == false:
        raise newException(ValueError, "Couldn't set the Send's proof.")

    #Set the sender.
    if not result.setSender(input):
        raise newException(ValueError, "Couldn't set the Node's sender.")

    #Set the signature.
    if not result.setSignature(signature):
        raise newException(ValueError, "Couldn't set the Node's signature.")
