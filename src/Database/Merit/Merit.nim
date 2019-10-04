#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Consensus lib.
import ../Consensus/Consensus

#Merit DB lib.
import ../Filesystem/DB/MeritDB

#Merit libs.
import Difficulty
import BlockHeader
import Block
import Blockchain
import State
import Epochs

export Difficulty
export BlockHeader
export Block
export Blockchain
export State
export Epochs

#Tables standard lib.
import tables

#Blockchain, State, and Epochs wrapper.
type Merit* = ref object
    blockchain*: Blockchain
    state*: State
    epochs*: Epochs

#Constructor.
proc newMerit*(
    db: DB,
    consensus: Consensus,
    genesis: string,
    blockTime: int,
    startDifficultyArg: string,
    live: int
): Merit {.forceCheck: [].} =
    #Extract the Difficulty.
    var startDifficulty: Hash[384]
    try:
        startDifficulty = startDifficultyArg.toHash(384)
    except ValueError as e:
        doAssert(false, "Invalid chain specs (start difficulty) passed to newMerit: " & e.msg)

    #Create the Merit object.
    result = Merit(
        blockchain: newBlockchain(
            db,
            genesis,
            blockTime,
            startDifficulty
        )
    )
    result.state = newState(db, live, result.blockchain.height)
    result.epochs = newEpochs(consensus, result.blockchain)

#Add a Block to the Blockchain.
proc processBlock*(
    merit: Merit,
    newBlock: Block
) {.forceCheck: [
    ValueError,
    DataExists,
    NotConnected
].} =
    try:
        merit.blockchain.processBlock(newBlock)
    except ValueError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except NotConnected as e:
        fcRaise e

#Process a Block already addded to the Blockchain.
proc postProcessBlock*(
    merit: Merit,
    consensus: Consensus
): Epoch {.forceCheck: [].} =
    #Calculate the packets in the tail Block.
    var packets: Table[Hash[384], VerificationPacket] = merit.blockchain.getPackets(consensus, merit.blockchain.height - 1)

    #Have the Epochs process the Block and return the popped Epoch.
    result = merit.epochs.shift(
        merit.blockchain.tip,
        packets
    )

    #Have the state process the block.
    merit.state.processBlock(merit.blockchain)
