#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet libraries.
import ../../../Wallet/Address
import ../../../Wallet/Wallet

#Entry object and Data object.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/DataObj

#Serialize common functions.
import ../SerializeCommon

#Finals lib.
import finals

#Parse a Data.
proc parseData*(
    dataStr: string
): Data {.raises: [
    ValueError,
    ArgonError,
    FinalAttributeError
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
        #Get the sender's Public Key.
        sender: EdPublicKey = newEdPublicKey(keyNonce[0])
        #Get the sender's address.
        senderAddress: string = newAddress(sender)
        #Get the nonce.
        nonce: uint = uint(keyNonce[1].fromBinary())
        #Get the proof.
        proof: uint = uint(proofSig[0].fromBinary())
        #Get the signature.
        signature: string = proofSig[1]

    #Create the Data.
    result = newDataObj(
        data
    )
    #Set the sender.
    result.sender = senderAddress
    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.hash = Blake512(keyNonce[0] & keyNonce[1] & char(result.data.len) & data)
    #Set the proof.
    result.proof = proof
    #Set the Argon hash.
    result.argon = Argon(result.hash.toString(), proof.toBinary(), true)

    #Set the signature.
    result.signature = signature
