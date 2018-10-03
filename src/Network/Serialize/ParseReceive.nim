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

#Serialize/Deserialize functions.
import SerializeCommon
import SerializeReceive

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Parse a Receive.
proc parseReceive*(recvStr: string): Receive {.raises: [ValueError, FinalAttributeError, Exception].} =
    var
        #Public Key | Nonce | Input Address | Input Nonce | Signature
        recvSeq: seq[string] = recvStr.deserialize(5)
        #Get the sender's Public Key.
        sender: PublicKey = newPublicKey(recvSeq[0].pad(32, $char(0)))
        #Get the nonce.
        nonce: BN = recvSeq[1].toBN(256)
        #Get the input Address.
        inputAddress: string = newAddress(recvSeq[2])
        #Get the input nonce.
        inputNonce: BN = recvSeq[3].toBN(256)
        #Get the signature.
        signature: string = recvSeq[4].pad(64, $char(0))

    #Create the Receive.
    result = newReceiveObj(
        inputAddress,
        inputNonce
    )

    #Set the sender.
    result.sender = sender.newAddress()
    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.hash = SHA512(result.serialize())

    #Verify the signature.
    if not sender.verify($result.hash, signature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature = signature
