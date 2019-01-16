#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Block Header, VerifierIndex, and Miners objects.
import BlockHeaderObj
import VerifierIndexObj
import MinersObj

#Serialization libs.
import ../../../Network/Serialize/Merit/SerializeBlockHeader
import ../../../Network/Serialize/Merit/SerializeMiners

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Define the Block class.
type Block* = ref object of RootObj
    #Block Header.
    header*: BlockHeader
    #Hash of the Block Header.
    hash*: ArgonHash

    #Verifications.
    verifications*: seq[VerifierIndex]
    #Who to attribute the Merit to (amount is 0 (exclusive) to 100 (inclusive)).
    miners*: Miners

#Set the Miners.
proc `miners=`*(newBlock: Block, miners: Miners) =
    newBlock.miners = miners
    newBlock.header.miners = miners

#Constructor.
proc newBlockObj*(
    nonce: uint,
    last: ArgonHash,
    aggregate: BLSSignature,
    indexes: seq[VerifierIndex],
    miners: Miners,
    time: uint = getTime(),
    proof: uint = 0
): Block {.raises: [ValueError, ArgonError].} =
    #Verify the Miners, unless this is the genesis Block.
    if nonce != 0:
        var total: uint = 0
        if (miners.len < 1) or (100 < miners.len):
            raise newException(ValueError, "Invalid Miners quantity.")
        for miner in miners:
            total += miner.amount
            if (miner.amount < 1) or (uint(100) < miner.amount):
                raise newException(ValueError, "Invalid Miner amount.")
        if total != 100:
            raise newException(ValueError, "Invalid total Miner amount.")

    #Create the Block.
    result = Block(
        header: newBlockheaderObj(
            nonce,
            last,
            aggregate,
            miners.calculateMerkle(),
            time,
            proof
        ),
        verifications: indexes,
        miners: miners
    )

    #Set the Header hash.
    result.hash = Argon(result.header.serialize(), result.header.proof.toBinary())
