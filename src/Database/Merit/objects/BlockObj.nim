#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib (for BLSSignature).
import ../../../Wallet/MinerWallet

#Block Header lib.
import ../BlockHeader

#MeritHolderRecord and Miners objects.
import ../../common/objects/MeritHolderRecordObj
import MinersObj

#Finals lib.
import finals

#Tables standard lib.
import tables

#Define the Block class.
type Block* = object
    #Block Header.
    header*: BlockHeader

    #MeritHolder Records.
    records: seq[MeritHolderRecord]
    #Who to attribute the Merit to (amount is 0 (exclusive) to 100 (inclusive)).
    miners: Miners

#Records getter/setter.
func records*(
    blockArg: Block
): seq[MeritHolderRecord] {.inline, forceCheck: [].} =
    blockArg.records

func `records=`*(
    blockArg: var Block,
    records: seq[MeritHolderRecord]
) {.forceCheck: [
    ValueError
].} =
    #Verify no MeritHolder has multiple Records.
    var
        holders: Table[string, bool] = initTable[string, bool]()
        holder: string
    for record in records:
        holder = record.key.toString()
        if holders.hasKey(holder):
            raise newException(ValueError, "One MeritHolder has two Records.")
        holders[holder] = true

    blockArg.records = records

#Miners getter/setter.
func miners*(
    blockArg: Block
): Miners {.inline, forceCheck: [].} =
    blockArg.miners

func `miners=`*(
    blockArg: var Block,
    miners: Miners
) {.forceCheck: [
    ValueError
].} =
    #Verify the Miners, unless this is the genesis Block.
    if blockArg.header.nonce != 0:
        if (miners.miners.len < 1) or (100 < miners.miners.len):
            raise newException(ValueError, "Invalid Miners quantity.")

        var total: int = 0
        for miner in miners.miners:
            if (miner.amount < 1) or (100 < miner.amount):
                raise newException(ValueError, "Invalid Miner amount.")
            total += miner.amount
        if total != 100:
            raise newException(ValueError, "Invalid total Miner amount.")

    blockArg.miners = miners
    blockArg.header.miners = miners.merkle.hash

#Constructor.
func newBlockObj*(
    nonce: Natural,
    last: ArgonHash,
    aggregate: BLSSignature,
    records: seq[MeritHolderRecord],
    miners: Miners,
    time: int64 = getTime(),
    proof: Natural = 0
): Block {.forceCheck: [
    ValueError,
    ArgonError
].} =
    #Create the Block Header.
    var header: BlockHeader
    try:
        header = newBlockheader(
            nonce,
            last,
            aggregate,
            miners.merkle.hash,
            time,
            proof
        )
    except ArgonError as e:
        fcRaise e

    #Create the Block.
    result = Block(
        header: header
    )
    #Unorthodox syntax used to call our custom setters.
    try:
        `records=`(result, records)
        `miners=`(result, miners)
    except ValueError as e:
        fcRaise e
