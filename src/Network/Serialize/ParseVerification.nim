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

#Serialize/Deserialize functions.
import SerializeCommon
import SerializeVerification

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Parse a Verification.
proc parseVerification*(
    verifStr: string
): Verification {.raises: [
    ValueError,
    SodiumError,
    FinalAttributeError
].} =
    var
        #Public Key | Nonce | Send Hash | Signature
        verifSeq: seq[string] = verifStr.deserialize(4)
        #Get the Verifier's Public Key.
        verifier: PublicKey = newPublicKey(verifSeq[0].pad(32, char(0)))
        #Get the Verifier's address based off the Verifier's Public Key.
        address: string = newAddress(verifier)
        #Get the nonce.
        nonce: BN = verifSeq[1].toBN(256)
        #Get the send hash.
        send: string = verifSeq[2].toHex().pad(128)
        #Get the signature.
        signature: string = verifSeq[3].pad(64, char(0))

    #Create the Verification.
    result = newVerificationObj(
        send.toArgonHash()
    )

    #Set the Sender.
    result.sender = address
    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.hash = SHA512(result.serialize())

    #Verify the signature.
    if not verifier.verify(result.hash.toString(), signature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature = signature
