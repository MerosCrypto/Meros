#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Hash lib.
import ../../../../../lib/Hash

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#Element libs.
import ../../../../Consensus/Elements/Elements

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
    ValueError
].} =
    #Header | Body
    var
        header: BlockHeader
        bodyStr: string

    #Parse the header.
    try:
        header = blockStr.parseBlockHeader()
    except ValueError as e:
        raise e

    #Grab the body.
    bodyStr = blockStr.substr(
        BLOCK_HEADER_DATA_LEN +
        (if header.newMiner: BLS_PUBLIC_KEY_LEN else: NICKNAME_LEN) +
        INT_LEN + INT_LEN + BLS_SIGNATURE_LEN
    )

    #Packets Length | Packets | Amount of Elements | Elements | Aggregate Signature
    var
        packetsLen: int = bodyStr[0 ..< INT_LEN].fromBinary()
        packetsStart: int = INT_LEN

        packets: seq[VerificationPacket] = newSeq[VerificationPacket](packetsLen)
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

    i = packetsStart
    if bodyStr.len < i + NICKNAME_LEN:
        raise newException(ValueError, "DB parseBlock not handed enough data to get the amount of holders in the next VerificationPacket.")

    var holders: seq[uint16]
    for p in 0 ..< packetsLen:
        holders = newSeq[uint16](bodyStr[i ..< i + NICKNAME_LEN].fromBinary())
        i += NICKNAME_LEN

        #The holders is represented by a NICKNAME_LEN. This uses an INT_LEN so the last packet checks the elements length.
        if bodyStr.len < i + (holders.len * NICKNAME_LEN) + HASH_LEN + INT_LEN:
            raise newException(ValueError, "DB parseBlock not handed enough data to get the holders in this VerificationPacket, its hash, and the amount of holders in the next VerificationPacket.")

        for h in 0 ..< holders.len:
            holders[h] = uint16(bodyStr[i ..< i + NICKNAME_LEN].fromBinary())
            i += NICKNAME_LEN

        try:
            packets[p] = newVerificationPacketObj(bodyStr[i ..< i + HASH_LEN].toHash(384))
            i += HASH_LEN
        except ValueError as e:
            raise e
        packets[p].holders = holders

    elementsLen = bodyStr[i ..< i + INT_LEN].fromBinary()
    i += INT_LEN
    for e in 0 ..< elementsLen:
        try:
            pbeResult = bodyStr.parseBlockElement(i)
        except ValueError as e:
            raise e
        i += pbeResult.len
        elements.add(pbeResult.element)

    if bodyStr.len < i + BLS_SIGNATURE_LEN:
        raise newException(ValueError, "DB parseBlock not handed enough data to get the aggregate signature.")

    try:
        aggregate = newBLSSignature(bodyStr[i ..< i + BLS_SIGNATURE_LEN])
    except BLSError:
        raise newException(ValueError, "Invalid aggregate signature.")

    #Create the Block Object.
    result = newBlockObj(
        header,
        newBlockBodyObj(
            packets,
            elements,
            aggregate
        )
    )
