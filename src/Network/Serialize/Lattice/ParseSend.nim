#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Entry object and Send object.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/SendObj

#Serialize common functions.
import ../SerializeCommon

#Parse a Send.
proc parseSend*(
    sendStr: string
): Send {.forceCheck: [
    ValueError,
    ArgonError,
    EdPublicKeyError
].} =
    #Public Key | Nonce | Output | Amount | Proof | Signature
    var sendSeq: seq[string] = sendStr.deserialize(
        PUBLIC_KEY_LEN,
        INT_LEN,
        PUBLIC_KEY_LEN,
        MEROS_LEN,
        SIGNATURE_LEN,
        INT_LEN
    )

    #Create the Send.
    try:
        result = newSendObj(
            newAddress(sendSeq[2]),
            uint64(sendSeq[3].fromBinary())
        )
    except EdPublicKeyError as e:
        fcRaise e

    try:
        #Set the sender.
        result.sender = newAddress(sendSeq[0])
        #Set the nonce.
        result.nonce = sendSeq[1].fromBinary()

        #Set the Blake384 hash.
        result.hash = Blake384("send" & sendSeq.reserialize(0, 3))
        #Set the proof.
        result.proof = sendSeq[5].fromBinary()

        #Set the Argon hash.
        result.argon = Argon(result.hash.toString(), result.proof.toBinary(), true)
        #Set the signature.
        result.signature = newEdSignature(sendSeq[4])
        result.signed = true
    except ValueError as e:
        fcRaise e
    except ArgonError as e:
        fcRaise e
    except EdPublicKeyError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Mint: " & e.msg)
