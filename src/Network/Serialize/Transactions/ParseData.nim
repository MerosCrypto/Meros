#Errors lib.
import ../../../lib/Errors

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
    dataStr: string,
    diff: Hash[384]
): Data {.forceCheck: [
    ValueError,
    Spam
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

    var
        hash: Hash[384] = Blake384("\3" & dataSeq[0] & dataSeq[2])
        argon: ArgonHash = Argon(hash.toString(), dataSeq[4].pad(8), true)
    if argon < diff:
        raise newSpam("Data didn't beat the difficulty.", hash, argon)

    #Create the Data.
    try:
        result = newDataObj(
            dataSeq[0].toHash(384),
            dataSeq[2]
        )
    except ValueError as e:
        raise e

    #Hash it and set its signature/proof/argon.
    result.hash = hash

    try:
        result.signature = newEdSignature(dataSeq[3])
    except ValueError as e:
        raise e

    result.proof = uint32(dataSeq[4].fromBinary())
    result.argon = argon
