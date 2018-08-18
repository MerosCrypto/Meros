#Errors lib.
import ../../lib/Errors

#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#SHA512 lib.
import ../../lib/Argon

#Node object and Receive object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/ReceiveObj

#delim character/serialize function.
import common
import SerializeReceive

#String utils standard lib.
import strutils

#Parse a Receive.
proc parse*(recvStr: string): Receive {.raises: [ValueError, Exception].} =
    var
        #Public Key | Nonce | Input Address | Input Nonce | Amount | Signature
        recvSeq: seq[string] = recvStr.split(delim)
        #Get the sender's Public Key.
        sender: PublicKey = recvSeq[0].toBN(255).toString(16).newPublicKey()
        #Get the nonce.
        nonce: BN = recvSeq[1].toBN(255)
        #Get the input Address.
        inputAddress: string = recvSeq[2].toBN(255).toString(16).newAddress()
        #Get the input nonce.
        inputNonce: BN = recvSeq[3].toBN(255)
        #Get the amount.
        amount: BN = recvSeq[4].toBN(255)
        #Get the signature.
        signature: string = recvSeq[5].toBN(255).toString(16)

    #Create the Receive.
    result = newReceiveObj(
        inputAddress,
        inputNonce,
        amount
    )

    #Set the descendant type.
    if not result.setDescendant(2):
        raise newException(ValueError, "Couldn't set the Node's descendant type.")

    #Set the nonce.
    if not result.setNonce(nonce):
        raise newException(ValueError, "Couldn't set the Node's nonce.")

    #Verify the signature.
    if sender.verify(result.getHash(), signature) == false:
        raise newException(ValueError, "Received signature was invalid.")

    #Set the sender.
    if not result.setSender(sender.newAddress()):
        raise newException(ValueError, "Couldn't set the Node's sender.")

    #Set the signature.
    if not result.setSignature(signature):
        raise newException(ValueError, "Couldn't set the Node's signature.")
