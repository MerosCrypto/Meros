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

#Node object and Verification object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/VerificationObj

#delim character/serialize function.
import SerializeCommon
import SerializeVerification

#SetOnce lib.
import SetOnce

#String utils standard lib.
import strutils

#Parse a Verification.
proc parseVerification*(verifStr: string): Verification {.raises: [ValueError, Exception].} =
    var
        #Public Key | Nonce | Send Hash | Signature
        verifSeq: seq[string] = verifStr.toBN(253).toString(256).split(delim)
        #Get the Verifier's Public Key.
        verifier: PublicKey = verifSeq[0].toBN(255).toString(16).newPublicKey()
        #Get the Verifier's address based off the Verifier's Public Key.
        address: string = verifier.newAddress()
        #Get the nonce.
        nonce: BN = verifSeq[1].toBN(255)
        #Get the send hash.
        send: string = verifSeq[2].toBN(255).toString(16)
        #Get the signature.
        signature: string = verifSeq[3].toBN(255).toString(16).pad(128)

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
