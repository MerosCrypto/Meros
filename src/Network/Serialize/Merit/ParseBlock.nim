#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#VerifierRecord object.
import ../../../Database/common/objects/VerifierRecordObj

#Miners object.
import ../../../Database/Merit/objects/MinersObj

#BlockHeader and lib.
import ../../../Database/Merit/BlockHeader
import ../../../Database/Merit/Block

#Deserialize/parse functions.
import ../SerializeCommon
import ParseBlockHeader
import ParseRecords
import ParseMiners

#Parse a Block.
proc parseBlock*(
    blockStr: string
): Block {.forceCheck: [
    ValueError,
    ArgonError,
    BLSError
].} =
    #Header | Verifications | Miners
    var
        header: BlockHeader
        records: seq[VerifierRecord]
        miners: Miners
    try:
        header = blockStr.substr(0, BLOCK_HEADER_LEN - 1).parseBlockHeader()
        records = blockStr.substr(
            BLOCK_HEADER_LEN,
            BLOCK_HEADER_LEN + INT_LEN + (blockStr[BLOCK_HEADER_LEN ..< BLOCK_HEADER_LEN + 4].fromBinary() * VERIFIER_INDEX_LEN)
        ).parseRecords()
        miners = blockStr.substr(
            BLOCK_HEADER_LEN + INT_LEN + (blockStr[BLOCK_HEADER_LEN ..< BLOCK_HEADER_LEN + 4].fromBinary() * VERIFIER_INDEX_LEN)
        ).parseMiners()
    except ValueError as e:
        fcRaise e
    except ArgonError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    #Create the Block Object.
    try:
        result = newBlockObj(
            header.nonce,
            header.last,
            header.aggregate,
            records,
            miners,
            header.time,
            header.proof
        )
    except ValueError as e:
        fcRaise e
    except ArgonError as e:
        fcRaise e
