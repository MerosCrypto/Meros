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

#Node object and Verification object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/VerificationObj

#Serialize/Deserialize functions.
import SerializeCommon
import SerializeVerification

#SetOnce lib.
import SetOnce

#String utils standard lib.
import strutils

#Parse a Verification.
proc parseVerification*(verifStr: string): Verification {.raises: [ValueError].} =
    var
        #Public Key | Nonce | Send Hash | Signature
        verifSeq: seq[string] = verifStr.deserialize(4)
        #Get the Verifier's Public Key.
        verifier: PublicKey = newPublicKey(verifSeq[0].toHex())
        #Get the Verifier's address based off the Verifier's Public Key.
        address: string = newAddress(verifier)
        #Get the nonce.
        nonce: BN = verifSeq[1].toBN(256)
        #Get the send hash.
        send: string = verifSeq[2].toHex().pad(128)
        #Get the signature.
        signature: string = verifSeq[3].toHex().pad(128)

    #Create the Verification.
    result = newVerificationObj(
        send.toArgonHash()
    )

    #Set the Sender.
    result.sender.value = address
    #Set the nonce.
    result.nonce.value = nonce
    #Set the hash.
    result.hash.value = SHA512(result.serialize())

    #Verify the signature.
    if not verifier.verify($result.hash.toValue(), signature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature.value = signature
