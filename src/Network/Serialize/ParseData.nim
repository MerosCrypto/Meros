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

#Node object and Data object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/DataObj

#Serialize function.
import SerializeCommon
import SerializeData

#SetOnce lib.
import SetOnce

#String utils standard lib.
import strutils

#Parse a Data.
proc parseData*(sendStr: string): Data {.raises: [ResultError, ValueError, Exception].} =
    var
        #Public Key | Nonce | Data | Proof | Signature
        sendSeq: seq[string] = sendStr.deserialize(6)
        #Get the sender's Public Key.
        sender: PublicKey = newPublicKey(sendSeq[0].toHex())
        #Get the sender's address.
        senderAddress: string = newAddress(sender)
        #Get the nonce.
        nonce: BN = sendSeq[1].toBN(256)
        #Get the data.
        data: string = sendSeq[2]
        #Get the proof.
        proof: string = sendSeq[3]
        #Get the signature.
        signature: string = sendSeq[4].toHex().pad(128)

    #Create the Data.
    result = newDataObj(
        data
    )
    #Set the sender.
    result.sender.value = senderAddress
    #Set the nonce.
    result.nonce.value = nonce
    #Set the SHA512 hash.
    result.sha512.value = SHA512(data)
    #Set the proof.
    result.proof.value = proof.toBN(256)
    #Set the hash.
    result.hash.value = Argon(result.sha512.toString(), proof, true)

    #Verify the signature.
    if not sender.verify($result.hash.toValue(), signature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature.value = signature
