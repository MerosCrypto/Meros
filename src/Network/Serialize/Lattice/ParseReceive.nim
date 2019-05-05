#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#LatticeIndex object,
import ../../../Database/common/objects/LatticeIndexObj

#Entry and Receive objects.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/ReceiveObj

#Serialize common functions.
import ../SerializeCommon

#Parse a Receive.
proc parseReceive*(
    recvStr: string
): Receive {.forceCheck: [
    EdPublicKeyError
].} =
    #Public Key | Nonce | Input Key | Input Nonce | Signature
    var recvSeq: seq[string] = recvStr.deserialize(
        PUBLIC_KEY_LEN,
        INT_LEN,
        PUBLIC_KEY_LEN,
        INT_LEN,
        SIGNATURE_LEN
    )

    #Create the Receive.
    try:
        result = newReceiveObj(
            newLatticeIndex(
                newAddress(recvSeq[2]),
                recvSeq[3].fromBinary()
            )
        )
    except EdPublicKeyError as e:
        fcRaise e

    try:
        #Set the sender.
        try:
            result.sender = newAddress(recvSeq[0])
        except EdPublicKeyError as e:
            fcRaise e
        
        #Set the nonce.
        result.nonce = recvSeq[1].fromBinary()

        #Set the hash.
        result.hash = Blake384("receive" & recvSeq.reserialize(1, 3))
        #Set the signature.
        result.signature = newEdSignature(recvSeq[4])
        result.signed = true
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Receive: " & e.msg)
