#Errors lib.
import ../../../lib/Errors

#MeritHolderRecord and Miners objects.
import ../../common/objects/MeritHolderRecordObj
import MinersObj

#BlockBody object.
type BlockBody* = object
    #MeritHolder Records.
    records*: seq[MeritHolderRecord]
    #Who to attribute the Merit to (amount is 0 (exclusive) to 100 (inclusive)).
    miners*: Miners

#Constructor.
func newBlockBodyObj*(
    records: seq[MeritHolderRecord],
    miners: Miners
): BlockBody {.inline, forceCheck: [].} =
    BlockBody(
        records: records,
        miners: miners
    )
