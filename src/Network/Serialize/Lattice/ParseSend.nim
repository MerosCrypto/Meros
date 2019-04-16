#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BN/Raw lib.
import ../../../lib/Raw

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
    var
        #Public Key | Nonce | Output | Amount | Proof | Signature
        sendSeq: seq[string] = sendStr.deserialize(
            PUBLIC_KEY_LEN,
            INT_LEN,
            PUBLIC_KEY_LEN,
            MEROS_LEN,
            INT_LEN,
            SIGNATURE_LEN
        )
        #Sender.
        sender: string
        #Get the nonce.
        nonce: int = sendSeq[1].fromBinary()
        #Output.
        output: string
        #Get the amount.
        amount: BN = sendSeq[3].toBNFromRaw()
        #Get the proof.
        proof: string = sendSeq[4]
        #Get the signature.
        signature: string = sendSeq[5]

    try:
        sender = newAddress(sendSeq[0])
        output = newAddress(sendSeq[2])
    except EdPublicKeyError as e:
        raise e

    #Create the Send.
    result = newSendObj(
        output,
        amount
    )

    try:
        #Set the sender.
        result.sender = sender
        #Set the nonce.
        result.nonce = nonce

        #Set the Blake384 hash.
        result.hash = Blake384(sendSeq.reserialize(0, 3))
        #Set the proof.
        result.proof = proof.fromBinary()

        #Set the Argon hash.
        result.argon = Argon(result.hash.toString(), proof, true)
        #Set the signature.
        result.signature = signature
    except ValueError as e:
        raise e
    except ArgonError as e:
        raise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Mint: " & e.msg)
