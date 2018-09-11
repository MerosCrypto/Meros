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

#Node object and Receive object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/ReceiveObj

#delim character/serialize function.
import SerializeCommon
import SerializeReceive

#String utils standard lib.
import strutils

#Parse a Receive.
proc parseReceive*(recvStr: string): Receive {.raises: [ValueError, Exception].} =
    var
        #Public Key | Nonce | Input Address | Input Nonce  | Signature
        recvSeq: seq[string] = recvStr.toBN(253).toString(256).split(delim)
        #Get the sender's Public Key.
        sender: PublicKey = recvSeq[0].toBN(255).toString(16).newPublicKey()
        #Get the nonce.
        nonce: BN = recvSeq[1].toBN(255)
        #Get the input Address.
        inputAddress: string = recvSeq[2].toBN(255).toString(16).newAddress()
        #Get the input nonce.
        inputNonce: BN = recvSeq[3].toBN(255)
        #Get the signature.
        signature: string = recvSeq[4].toBN(255).toString(16).pad(128)

    #Create the Receive.
    result = newReceiveObj(
        inputAddress,
        inputNonce
    )

    #Set the nonce.
    if not result.setNonce(nonce):
        raise newException(ValueError, "Couldn't set the Node's nonce.")

    #Set the hash.
    if not result.setHash(SHA512(result.serialize())):
        raise newException(ResultError, "Couldn't set the node hash.")

    #Verify the signature.
    if not sender.verify(result.getHash(), signature):
        raise newException(ValueError, "Received signature was invalid.")

    #Set the sender.
    if not result.setSender(sender.newAddress()):
        raise newException(ValueError, "Couldn't set the Node's sender.")

    #Set the signature.
    if not result.setSignature(signature):
        raise newException(ValueError, "Couldn't set the Node's signature.")
