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

#Node object and MeritRemoval object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/MeritRemovalObj

#Deserialize function.
import SerializeCommon
import SerializeMeritRemoval

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Parse a MeritRemoval.
proc parseMeritRemoval*(sendStr: string): MeritRemoval {.raises: [ValueError, FinalAttributeError, Exception].} =
    var
        #Public Key | Nonce | First | Second | Signature
        dataSeq: seq[string] = sendStr.deserialize(6)
        #Get the sender's Public Key.
        sender: PublicKey = newPublicKey(dataSeq[0].pad(32, $char(0)))
        #Get the sender's address.
        senderAddress: string = newAddress(sender)
        #Get the nonce.
        nonce: BN = dataSeq[1].toBN(256)
        #Get the hash of the first node.
        first: Hash[512] = dataSeq[2].pad(64, $char(0)).toHash(512)
        #Get the hash of the second node.
        second: Hash[512] = dataSeq[3].pad(64, $char(0)).toHash(512)
        #Get the signature.
        signature: string = dataSeq[4].pad(64, $char(0))

    #Create the MeritRemoval.
    result = newMeritRemovalObj(
        first,
        second
    )
    #Set the sender.
    result.sender = senderAddress
    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.hash = SHA512(result.serialize())

    #Verify the signature.
    if not sender.verify($result.hash, signature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature = signature
