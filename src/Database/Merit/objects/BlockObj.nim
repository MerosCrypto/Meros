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

#VerifierRecord and Miners objects.
import ../../common/objects/VerifierRecordObj
import MinersObj

#Finals lib.
import finals

#Define the Block class.
type Block* = object
    #Block Header.
    header*: BlockHeader

    #Verifier Records.
    records*: seq[VerifierRecord]
    #Who to attribute the Merit to (amount is 0 (exclusive) to 100 (inclusive)).
    miners: Miners

#Miners getter/setter.
func miners*(
    blockArg: Block
): Miners {.inline, forceCheck: [].} =
    blockArg.miners

#Update the Block Header with the new miner merkle.
func `miners=`*(
    blockArg: var Block,
    miners: Miners
) {.forceCheck: [].} =
    blockArg.miners = miners
    blockArg.header.miners = miners.merkle.hash

#Constructor.
func newBlockObj*(
    nonce: Natural,
    last: ArgonHash,
    aggregate: BLSSignature,
    records: seq[VerifierRecord],
    miners: Miners,
    time: int64 = getTime(),
    proof: Natural = 0
): Block {.forceCheck: [
    ValueError,
    ArgonError
].} =
    #Verify the Miners, unless this is the genesis Block.
    if nonce != 0:
        var total: int = 0
        if (miners.miners.len < 1) or (100 < miners.miners.len):
            raise newException(ValueError, "Invalid Miners quantity.")
        for miner in miners.miners:
            total += miner.amount
            if (miner.amount < 1) or (100 < miner.amount):
                raise newException(ValueError, "Invalid Miner amount.")
        if total != 100:
            raise newException(ValueError, "Invalid total Miner amount.")

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
        raise e

    #Create the Block.
    result = Block(
        header: header,
        records: records,
        miners: miners
    )
