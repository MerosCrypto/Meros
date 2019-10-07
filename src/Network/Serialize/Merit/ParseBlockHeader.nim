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

#Parse function.
proc parseBlockHeader*(
    headerStr: string
): BlockHeader {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Version | Last | Contents | Verifiers | New Miner | Miner | Time | Proof | Signature
    var headerSeq: seq[string] = headerStr.deserialize(
        INT_LEN,
        HASH_LEN,
        HASH_LEN,
        HASH_LEN,
        BYTE_LEN
    )

    #Extract the rest of the header.
    headerSeq = headerSeq & headerStr[
        INT_LEN + HASH_LEN + HASH_LEN + HASH_LEN + BYTE_LEN ..< headerStr.len
    ].deserialize(
        if headerSeq[4] == "\0": NICKNAME_LEN else: BLS_PUBLIC_KEY_LEN,
        INT_LEN,
        INT_LEN,
        BLS_SIGNATURE_LEN
    )

    #Create the BlockHeader.
    try:
        if headerSeq[4] == "\0":
            result = newBlockHeaderObj(
                uint32(headerSeq[0].fromBinary()),
                headerSeq[1].toArgonHash(),
                headerSeq[2].toHash(384),
                headerSeq[3].toHash(384),
                uint16(headerSeq[5].fromBinary()),
                uint32(headerSeq[6].fromBinary()),
                uint32(headerSeq[7].fromBinary()),
                newBLSSignature(headerSeq[8])
            )
        else:
            result = newBlockHeaderObj(
                uint32(headerSeq[0].fromBinary()),
                headerSeq[1].toArgonHash(),
                headerSeq[2].toHash(384),
                headerSeq[3].toHash(384),
                newBLSPublicKey(headerSeq[5]),
                uint32(headerSeq[6].fromBinary()),
                uint32(headerSeq[7].fromBinary()),
                newBLSSignature(headerSeq[8])
            )
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e
    hash(
        result,
        headerStr[0 ..< (
                INT_LEN + HASH_LEN + HASH_LEN + HASH_LEN + BYTE_LEN +
                (if headerSeq[4] == "\0": NICKNAME_LEN else: BLS_PUBLIC_KEY_LEN) +
                INT_LEN
            )
        ]
    )
