#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Data object.
import ../../../Database/Transactions/objects/DataObj

#Common serialization functions.
import ../SerializeCommon

#Parse function.
proc parseData*(
    dataStr: string
): Data {.forceCheck: [
    ValueError
].} =
    #Verify the input length.
    if dataStr.len < HASH_LEN + BYTE_LEN:
        raise newException(ValueError, "parseData not handed enough data to get the length of the data.")

    if dataStr.len < HASH_LEN + BYTE_LEN + int(dataStr[HASH_LEN]) + BYTE_LEN:
        raise newException(ValueError, "parseData not handed enough data to get the data.")

    #Input | Data Length | Data | Signature | Proof
    var dataSeq: seq[string] = dataStr.deserialize(
        HASH_LEN,
        BYTE_LEN,
        int(dataStr[HASH_LEN]),
        ED_SIGNATURE_LEN,
        INT_LEN
    )

    #Create the Data.
    try:
        result = newDataObj(
            dataSeq[0].toHash(384),
            dataSeq[2]
        )
    except ValueError as e:
        fcRaise e

    #Hash it and set its signature/proof/argon.
    try:
        result.hash = Blake384("\3" & dataSeq[0] & dataSeq[2])

        try:
            result.signature = newEdSignature(dataSeq[3])
        except ValueError as e:
            fcRaise e

        result.proof = uint32(dataSeq[4].fromBinary())
        result.argon = Argon(result.hash.toString(), result.proof.toBinary().pad(8), true)
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Data: " & e.msg)
