#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#MeritHolderRecord object.
import ../../../Database/common/objects/MeritHolderRecordObj

#Miners and BlockBody objects.
import ../../../Database/Merit/objects/MinersObj
import ../../../Database/Merit/objects/BlockBodyObj

#Deserialize/parse functions.
import ../SerializeCommon
import ParseRecords
import ParseMiners

#Parse a BlockBody.
proc parseBlockBody*(
    bodyStr: string
): BlockBody {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Records | Miners
    var
        recordsLen: int
        records: seq[MeritHolderRecord]
        miners: Miners
    try:
        recordsLen = INT_LEN + (bodyStr.substr(0, INT_LEN - 1).fromBinary() * MERIT_HOLDER_RECORD_LEN)
        records = bodyStr.substr(0, recordsLen).parseRecords()
        miners = bodyStr.substr(recordsLen).parseMiners()
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    #Create the BlockBody Object
    result = newBlockBodyObj(
        records,
        miners
    )
