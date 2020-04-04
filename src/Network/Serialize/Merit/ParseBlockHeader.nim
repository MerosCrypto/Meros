#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#BlockHeader object.
import ../../../Database/Merit/objects/BlockHeaderObj

#Common serialization functions.
import ../SerializeCommon

#Parse functions.
proc parseBlockHeader*(
    headerStr: string,
    interimHash: string,
    hash: RandomXHash
): BlockHeader {.forceCheck: [
    ValueError
].} =
    #Version | Last | Contents | Significant | Sketch Salt | Sketch Check | New Miner | Miner | Time | Proof | Signature
    var headerSeq: seq[string] = headerStr.deserialize(
        INT_LEN,
        HASH_LEN,
        HASH_LEN,
        NICKNAME_LEN,
        INT_LEN,
        HASH_LEN,
        BYTE_LEN
    )

    #Extract the rest of the header.
    headerSeq = headerSeq & headerStr[
        BLOCK_HEADER_DATA_LEN ..< headerStr.len
    ].deserialize(
        if headerSeq[6] == "\0": NICKNAME_LEN else: BLS_PUBLIC_KEY_LEN,
        INT_LEN,
        INT_LEN,
        BLS_SIGNATURE_LEN
    )

    #Create the BlockHeader.
    try:
        if headerSeq[6] == "\0":
            result = newBlockHeaderObj(
                uint32(headerSeq[0].fromBinary()),
                headerSeq[1].toRandomXHash(),
                headerSeq[2].toHash(256),
                uint16(headerSeq[3].fromBinary()),
                headerSeq[4],
                headerSeq[5].toHash(256),
                uint16(headerSeq[7].fromBinary()),
                uint32(headerSeq[8].fromBinary()),
                uint32(headerSeq[9].fromBinary()),
                newBLSSignature(headerSeq[10])
            )
        else:
            result = newBlockHeaderObj(
                uint32(headerSeq[0].fromBinary()),
                headerSeq[1].toRandomXHash(),
                headerSeq[2].toHash(256),
                uint16(headerSeq[3].fromBinary()),
                headerSeq[4],
                headerSeq[5].toHash(256),
                newBLSPublicKey(headerSeq[7]),
                uint32(headerSeq[8].fromBinary()),
                uint32(headerSeq[9].fromBinary()),
                newBLSSignature(headerSeq[10])
            )
    except ValueError as e:
        raise e
    except BLSError:
        raise newLoggedException(ValueError, "Invalid Public Key or Signature.")

    #Set the hashes.
    result.interimHash = interimHash
    result.hash = hash

proc parseBlockHeader*(
    rx: RandomX,
    headerStr: string
): BlockHeader {.forceCheck: [
    ValueError
].} =
    try:
        result = parseBlockHeader(headerStr, "", Hash[256]())
    except ValueError as e:
        raise e

    #Set the BlockHeader's actual hash.
    rx.hash(
        result,
        headerStr[0 ..< (
                BLOCK_HEADER_DATA_LEN +
                (if result.newMiner: BLS_PUBLIC_KEY_LEN else: NICKNAME_LEN) +
                INT_LEN + INT_LEN
            )
        ]
    )
