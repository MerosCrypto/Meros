#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#MinerWallet lib.
import ../../Wallet/MinerWallet

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
  genesis: string,
  blockTime: int,
  initialDifficulty: uint64,
  deadBlocks: int
): Merit {.forceCheck: [].} =
  result = Merit(
    blockchain: newBlockchain(
      db,
      genesis,
      blockTime,
      initialDifficulty
    )
  )
  result.state = newState(db, deadBlocks, result.blockchain)
  result.epochs = newEpochs(result.blockchain)

#Add a Block to the Blockchain.
proc processBlock*(
  merit: Merit,
  newBlock: Block
) {.inline, forceCheck: [].} =
  merit.blockchain.processBlock(newBlock)

#Process a Block already addded to the Blockchain.
proc postProcessBlock*(
  merit: Merit
): (Epoch, uint16, int) {.forceCheck: [].} =
  #Have the Epochs process the Block and return the popped Epoch.
  result[0] = merit.epochs.shift(merit.blockchain.tail)

  #Have the state process the block.
  (result[1], result[2]) = merit.state.processBlock(merit.blockchain)

#Get the reverted miners/holders.
proc revertMinersAndHolders*(
  merit: Merit,
  height: int
): tuple[
  miners: Table[BLSPublicKey, uint16],
  holders: seq[BLSPublicKey]
] {.forceCheck: [].} =
  result.miners = merit.blockchain.miners
  result.holders = merit.state.holders
  for h in countdown(merit.blockchain.height - 1, height):
    try:
      var header: BlockHeader = merit.blockchain[h].header
      if header.newMiner:
        result.miners.del(header.minerKey)
        result.holders.delete(high(result.holders))
    except IndexError as e:
      panic("Couldn't get a Block needed to revert the miners and holders: " & e.msg)

#Revert the Blockchain/State/Epochs.
proc revert*(
  merit: Merit,
  height: int
) {.forceCheck: [].} =
  #Reverting the Blockchain reverts the State.
  merit.blockchain.revert(merit.state, height)
  #We don't have an Epochs reversion algorithm. We just rebuild it.
  #If the amount of Blocks reverted is greater than the Epochs length, this is faster.
  merit.epochs = newEpochs(merit.blockchain)
