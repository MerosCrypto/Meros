#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Entry object and Data object.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/DataObj

#Serialize common functions.
import ../SerializeCommon

#Parse a Data.
proc parseData*(
    dataStr: string
): Data {.forceCheck: [
    ValueError,
    ArgonError,
    EdPublicKeyError
].} =
    var
        #Public Key | Nonce | Data Len | Data | Proof | Signature
        keyNonce: seq[string] = dataStr.deserialize(
            PUBLIC_KEY_LEN,
            INT_LEN
        )
        data: string = dataStr.substr(
            PUBLIC_KEY_LEN + INT_LEN + BYTE_LEN,
            PUBLIC_KEY_LEN + INT_LEN + int(dataStr[PUBLIC_KEY_LEN + INT_LEN])
        )
        proofSig: seq[string] = dataStr
            .substr(
                PUBLIC_KEY_LEN + INT_LEN + BYTE_LEN + int(dataStr[PUBLIC_KEY_LEN + INT_LEN])
            )
            .deserialize(
                INT_LEN,
                SIGNATURE_LEN
            )
        #Sender.
        sender: string
        #Get the nonce.
        nonce: int = keyNonce[1].fromBinary()
        #Get the proof.
        proof: int = proofSig[0].fromBinary()
        #Get the signature.
        signature: string = proofSig[1]

    try:
        sender = newAddress(newEdPublicKey(keyNonce[0]))
    except EdPublicKeyError as e:
        raise e

    #Create the Data.
    result = newDataObj(
        data
    )
    try:
        #Set the sender.
        result.sender = sender
        #Set the nonce.
        result.nonce = nonce

        #Set the hash.
        result.hash = Blake384(keyNonce[0] & keyNonce[1] & char(result.data.len) & data)
        #Set the proof.
        result.proof = proof

        #Set the Argon hash.
        result.argon = Argon(result.hash.toString(), proof.toBinary(), true)
        #Set the signature.
        result.signature = signature
    except ValueError as e:
        raise e
    except ArgonError as e:
        raise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Data: " & e.msg)
