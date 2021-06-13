import sets, tables

import ../../lib/[Errors, Util]
import ../../Wallet/MinerWallet
import ../../objects/GlobalFunctionBoxObj

import ../Transactions/objects/TransactionObj

import ../Filesystem/DB/MeritDB

import Difficulty, BlockHeader, Block, Blockchain
import State, Epochs, Rewards

export Difficulty, BlockHeader, Block, Blockchain
export State, Epochs, Rewards

#Blockchain, State, and Epochs wrapper.
type Merit* = ref object
  blockchain*: Blockchain
  state*: State
  epochs*: Epochs

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

proc createEpochs*(
  merit: Merit,
  functions: GlobalFunctionBox
) {.inline, forceCheck: [].} =
  merit.epochs = newEpochs(functions, merit.blockchain)

#Add a Block to the Blockchain.
proc processBlock*(
  merit: Merit,
  newBlock: Block
) {.inline, forceCheck: [].} =
  merit.blockchain.processBlock(newBlock)

#Process a Block already addded to the Blockchain.
#Updates the State and Epochs. Needed due to how the TX/Consensus DAG flow.
proc postProcessBlock*(
  merit: Merit
): (HashSet[Input], StateChanges) {.forceCheck: [].} =
  #Have the Epochs process the Block and return the popped Epoch.
  result[0] = merit.epochs.shift(merit.blockchain.tail, uint(merit.blockchain.height))

  #Have the State process the block.
  result[1] = merit.state.processBlock(merit.blockchain)

#Theoretically revert the chain, returning the affected miners/holders.
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

proc revert*(
  merit: Merit,
  height: int
) {.forceCheck: [].} =
  #Reverting the Blockchain reverts the State as well.
  merit.blockchain.revert(merit.state, height)
  #We don't have an Epochs reversion algorithm. We just rebuild it.
  #If the amount of Blocks reverted is greater than the Epochs length, this is faster anyways.
  merit.epochs = newEpochs(merit.epochs.functions, merit.blockchain)
