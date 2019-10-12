#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Hash lib.
import ../../../../../lib/Hash

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#Element lib.
import ../../../../Consensus/Elements/Element

#Block lib.
import ../../../../Merit/Block

#Serialization common functions.
import ../../../../../Network/Serialize/SerializeCommon

#Parse BlockHeader lib.
import ../../../../../Network/Serialize/Merit/ParseBlockHeader

#Parse BlockElement lib.
import ../../../../../Network/Serialize/Consensus/ParseBlockElement

#Parse a Block.
proc parseBlock*(
    blockStr: string
): Block {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Header | Body
    var
        header: BlockHeader
        bodyStr: string

    #Parse the header.
    try:
        header = blockStr.parseBlockHeader()
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    #Grab the body.
    bodyStr = blockStr.substr(
        INT_LEN + HASH_LEN + HASH_LEN + HASH_LEN + BYTE_LEN +
        INT_LEN + INT_LEN + BLS_SIGNATURE_LEN +
        (if header.newMiner: BLS_PUBLIC_KEY_LEN else: NICKNAME_LEN)
    )

    #Significant | Sketch Salt | Transactions Length | Transactions | Packets | Amount of Elements | Elements | Aggregate Signature
    var
        bodySeq: seq[string] = bodyStr.deserialize(
            INT_LEN,
            INT_LEN,
            INT_LEN
        )
        transactions: seq[Hash[384]] = @[]
        packets: seq[VerificationPacket] = @[]

        transactionsStart: int = INT_LEN + INT_LEN + INT_LEN
        transactionsLen: int = bodySeq[2].fromBinary()
        packetsStart: int = transactionsStart + (transactionsLen * HASH_LEN)

        i: int

        elementsLen: int
        pbeResult: tuple[
            element: BlockElement,
            len: int
        ]
        elements: seq[BlockElement] = @[]

        aggregate: BLSSignature

    if bodyStr.len < packetsStart:
        raise newException(ValueError, "DB parseBlock not handed enough data to get the amount of Transactions.")

    try:
        for t in countup(transactionsStart, packetsStart - 1, HASH_LEN):
            transactions.add(bodyStr[t ..< t + HASH_LEN].toHash(384))
    except ValueError as e:
        fcRaise e

    i = packetsStart
    if bodyStr.len < i + NICKNAME_LEN:
        raise newException(ValueError, "DB parseBlock not handed enough data to get the amount of holders in the next VerificationPacket.")

    packets = newSeq[VerificationPacket](transactionsLen)
    for p in 0 ..< transactionsLen:
        packets[p] = newVerificationPacketObj(transactions[p])

        packets[p].holders = newSeq[uint16](int(bodyStr[i]))
        i += BYTE_LEN
        if bodyStr.len < i + (packets[p].holders.len * NICKNAME_LEN) + INT_LEN:
            raise newException(ValueError, "DB parseBlock not handed enough data to get the holders in this VerificationPacket/the amount of holders in the next VerificationPacket.")

        for h in 0 ..< packets[p].holders.len:
            packets[p].holders[h] = uint16(bodyStr[i + (h * NICKNAME_LEN) ..< i + ((h + 1) * NICKNAME_LEN)].fromBinary())
        i += packets[p].holders.len * NICKNAME_LEN

    elementsLen = bodyStr[i ..< i + 4].fromBinary()
    i += 4
    for e in 0 ..< elementsLen:
        try:
            pbeResult = bodyStr.parseBlockElement(i)
        except ValueError as e:
            fcRaise e
        except BLSError as e:
            fcRaise e
        i += pbeResult.len
        elements.add(pbeResult.element)

    if bodyStr.len < i + BLS_SIGNATURE_LEN:
        raise newException(ValueError, "DB parseBlock not handed enough data to get the aggregate signature.")

    try:
        aggregate = newBLSSignature(bodyStr[i ..< i + BLS_SIGNATURE_LEN])
    except BLSError as e:
        fcRaise e

    #Create the Block Object.
    result = newBlockObj(
        header,
        newBlockBodyObj(
            bodySeq[0].fromBinary(),
            bodySeq[1],
            transactions,
            packets,
            elements,
            aggregate
        )
    )
