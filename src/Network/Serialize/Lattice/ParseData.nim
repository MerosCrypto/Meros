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
    if dataStr.len < PUBLIC_KEY_LEN + INT_LEN + 1:
        raise newException(ValueError, "parseData wasn't passed enough data to to get the data length.")

    var
        #Public Key | Nonce | Data Len | Data | Proof | Signature
        senderNonce: seq[string] = dataStr.deserialize(
            PUBLIC_KEY_LEN,
            INT_LEN
        )
        dataLen: int = int(dataStr[PUBLIC_KEY_LEN + INT_LEN])

    var
        data: string = dataStr.substr(
            PUBLIC_KEY_LEN + INT_LEN + BYTE_LEN,
            PUBLIC_KEY_LEN + INT_LEN + dataLen
        )
        sigProof: seq[string] = dataStr
            .substr(
                PUBLIC_KEY_LEN + INT_LEN + BYTE_LEN + dataLen
            )
            .deserialize(
                SIGNATURE_LEN,
                INT_LEN
            )

    #Create the Data.
    result = newDataObj(
        data
    )

    try:
        #Set the sender.
        try:
            result.sender = newAddress(senderNonce[0])
        except EdPublicKeyError as e:
            fcRaise e

        #Set the nonce.
        result.nonce = senderNonce[1].fromBinary()

        #Set the hash.
        result.hash = Blake384("data" & senderNonce[0] & senderNonce[1] & char(result.data.len) & data)
        #Set the proof.
        result.proof = sigProof[1].fromBinary()

        #Set the Argon hash.
        result.argon = Argon(result.hash.toString(), result.proof.toBinary(), true)
        #Set the signature.
        result.signature = newEdSignature(sigProof[0])
        result.signed = true
    except ValueError as e:
        fcRaise e
    except ArgonError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Data: " & e.msg)
