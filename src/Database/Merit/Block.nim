#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Verifications and Miners objects.
import objects/VerificationsObj
import objects/MinersObj

#BlockHeader and Block objects.
import objects/BlockHeaderObj
import objects/BlockObj
#Export the BlockHeader and Block objects.
export BlockHeaderObj
export BlockObj

#Finals lib.
import finals

#String utils standard library.
import strutils

#New Block function. Creates a new block. Raises an error if there's an issue.
proc newBlock*(
    nonce: uint,
    last: ArgonHash,
    verifications: Verifications,
    miners: Miners,
    proof: uint = 0,
    time: uint = getTime()
): Block {.raises: [
    ValueError,
    ArgonError
].} =
    #TODO: Verify the verifiers in the Verifications.

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
        nonce,
        last,
        miners,
        proof,
        time
    )
    result.verifications = verifications

#Increase the proof.
proc inc*(newBlock: Block) =
    #Increase the proof.
    inc(newBlock.proof)

    #Recalculate the Argon hash.
    newBlock.argon = Argon(newBlock.hash.toString(), newBlock.proof.toBinary())
