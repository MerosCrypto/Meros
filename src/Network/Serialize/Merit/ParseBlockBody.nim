#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element lib.
import ../../../Database/Consensus/Elements/Element

#BlockBody object.
import ../../../Database/Merit/objects/BlockBodyObj

#Deserialize/parse functions.
import ../SerializeCommon

#Parse a BlockBody.
proc parseBlockBody*(
    bodyStr: string
): BlockBody {.forceCheck: [
    ValueError
].} =
    #Verify the data length.
    var
        txLen: int
        elemLenPos: int
        elemLen: int
    if bodyStr.len < INT_LEN:
        raise newException(ValueError, "parseBlockBody not handed enough data to get the amount of Transactions.")
    txLen = bodyStr[0 ..< INT_LEN].fromBinary()
    elemLenPos = INT_LEN + (txLen * HASH_LEN)
    if bodyStr.len < elemLenPos + INT_LEN + BLS_SIGNATURE_LEN:
        raise newException(ValueError, "parseBlockBody not handed enough data to get the amount of Elements/the aggregate signature.")
    elemLen = bodyStr[elemLenPos ..< elemLenPos + INT_LEN].fromBinary()

    if elemLen != 0:
        doAssert(false, "parseBlockBody can't parse Blocks with Elements.")

    #Amount of Transactions | Transactions | Amount of Elements | Elements | Aggregate Signature
    var bodySeq: seq[string] = bodyStr.deserialize(
        INT_LEN,
        txLen * HASH_LEN,
        INT_LEN
    )
    var
        txs: seq[Hash[384]] = newSeq[Hash[384]](txLen)
        elementsStr: string = bodyStr[elemLenPos + INT_LEN ..< bodyStr.len - BLS_SIGNATURE_LEN]
        elements: seq[Element] = @[]
        aggregate: BLSSignature
    try:
        aggregate = newBLSSignature(bodyStr[bodyStr.len - BLS_SIGNATURE_LEN ..< bodyStr.len])
    except BLSError as e:
        doAssert(false, "Couldn't create a BLS Signature: " & e.msg)

    for t in 0 ..< txLen:
        try:
            txs[t] = bodySeq[1][t * 48 ..< (t * 48) + 48].toHash(384)
        except ValueError as e:
            doAssert(false, "Couldn't create a 48-byte hash from a 48-byte string: " & e.msg)

    for e in 0 ..< elemLen:
        discard elementsStr

    result = newBlockBodyObj(
        txs,
        elements,
        aggregate
    )
