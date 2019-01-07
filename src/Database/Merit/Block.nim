#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Verifications lib.
import ../Verifications/Verifications

#Index object.
import ../common/objects/IndexObj

#Miners object.
import objects/MinersObj

#BlockHeader and Block objects.
import objects/BlockHeaderObj
import objects/BlockObj
#Export the BlockHeader and Block objects.
export BlockHeaderObj
export BlockObj

#Serialization lib.
import ../../Network/Serialize/Merit/SerializeBlockHeader

#Finals lib.
import finals

#String utils standard library.
import strutils

#New Block function. Creates a new block. Raises an error if there's an issue.
proc newBlock*(
    verifs: Verifications,
    nonce: uint,
    last: ArgonHash,
    verifications: seq[Index],
    miners: Miners,
    time: uint = getTime(),
    proof: uint = 0
): Block {.raises: [
    ValueError,
    ArgonError,
    BLSError
].} =
    #Verify the Miners.
    var total: uint = 0
    if (miners.len < 1) or (100 < miners.len):
        raise newException(ValueError, "Invalid Miners quantity.")
    for miner in miners:
        total += miner.amount
        if (miner.amount < 1) or (uint(100) < miner.amount):
            raise newException(ValueError, "Invalid Miner amount.")
    if total != 100:
        raise newException(ValueError, "Invalid total Miner amount.")

    #Ceate the block.
    result = newBlockObj(
        verifs,
        nonce,
        last,
        verifications,
        miners,
        time,
        proof
    )

#Increase the proof.
proc inc*(newBlock: Block) =
    #Increase the proof.
    inc(newBlock.header.proof)

    #Recalculate the hash.
    newBlock.hash = Argon(newBlock.header.serialize(), newBlock.header.proof.toBinary())
