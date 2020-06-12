import deques

#Hash is imported so we can print them in error messages; not because we mutate or check them.
import ../../lib/[Errors, Hash]
import ../../Wallet/MinerWallet

import ../Filesystem/DB/MeritDB

import ../Consensus/Elements/objects/MeritRemovalObj

import objects/BlockchainObj
import BlockHeader, Block

import objects/StateObj
export StateObj

proc getNickname(
  state: var State,
  blockArg: Block,
  newBlock: bool = false,
  callNew: bool = true
): uint16 {.forceCheck: [].} =
  if blockArg.header.newMiner:
    try:
      result = state.reverseLookup(blockArg.header.minerKey)
    except IndexError:
      #Call new is only required by cacheNextRemoval which always has its miner registered.
      if newBlock:
        return state.newHolder(blockArg.header.minerKey)
      panic($blockArg.header.minerKey & " in Block " & $blockArg.header.hash & " doesn't have a nickname.")
  else:
    result = blockArg.header.minerNick

  #If this a holder with no Merit, who is regaining Merit, re-register them.
  if callNew and (state.merit[result] == 0):
    state.newHolder(result)

#Get the next removal which will happen.
proc cacheNextRemoval(
  state: var State,
  blockchain: Blockchain,
  height: int
) {.forceCheck: [].} =
  #Get the nonce of the Block which we'd be killing the Merit of.
  var nonce: int = height + state.pendingRemovals.len - state.deadBlocks - 1
  if state.pendingRemovals.len != 6:
    inc(nonce)

  #If the nonce is greater than 0, there's a Block to remove the Merit of.
  if nonce > 0:
    #Get the nickname for that Block.
    var nick: uint16
    try:
      nick = state.getNickname(blockchain[nonce], callNew = false)
    except IndexError as e:
      panic("State tried to remove dead Merit yet couldn't get the old Block: " & e.msg)

    #Do nothing if they had their Merit removed.
    var removals: seq[int] = state.loadHolderRemovals(nick)
    for removal in removals:
      if (removal < height) and (removal >= nonce):
        state.pendingRemovals.addLast(-1)
        return

    #Add the nickname.
    state.pendingRemovals.addLast(int(nick))
  #Else, mark that there isn't a removal.
  else:
    state.pendingRemovals.addLast(-1)

proc newState*(
  db: DB,
  deadBlocks: int,
  blockchain: Blockchain
): State {.forceCheck: [].} =
  result = newStateObj(db, deadBlocks, blockchain.height)
  for _ in 0 ..< 6:
    result.cacheNextRemoval(blockchain, blockchain.height)

proc processBlock*(
  state: var State,
  blockchain: Blockchain
): (uint16, int) {.forceCheck: [].} =
  logDebug "State processing Block", hash = blockchain.tail.header.hash

  #Init the result to who gained Merit/who had Merit die.
  try:
    result = (uint16(0), state.pendingRemovals.popFirst())
  except IndexError as e:
    panic("Couldn't pop the pending Dead Merit removal: " & e.msg)

  #Get the next Merit about to die.
  state.cacheNextRemoval(blockchain, blockchain.height)

  #Grab the new Block.
  var newBlock: Block = blockchain.tail

  #Save the amount of Unlocked Merit.
  state.saveUnlocked()

  #Add the miner's Merit to the State.
  var nick: uint16 = state.getNickname(newBlock, true)
  result[0] = nick
  state[nick] = state.merit[int(nick)] + 1

  #If there was a removal, decrement their Merit.
  if result[1] != -1:
    state[uint16(result[1])] = state.merit[result[1]] - 1

  var participants: set[uint16]
  for packet in newBlock.body.packets:
    for holder in packet.holders:
      participants.incl(holder)

  #Remove Merit from Merit Holders who had their Merit Removals archived in this Block.
  for elem in newBlock.body.elements:
    participants.incl(elem.holder)
    if elem of MeritRemoval:
      state.remove(elem.holder, blockchain.height - 1)

  #Increment the amount of processed Blocks.
  inc(state.processedBlocks)

  #Update every holder's Merit Status.
  for h in 0 ..< state.statuses.len:
    if participants.contains(uint16(h)):
      #Use the higher value to handle buffer periods.
      state.lastParticipation[h] = max(state.processedBlocks, state.lastParticipation[h])
      state.db.saveLastParticipation(uint16(h), state.lastParticipation[h])

    case state.statuses[h]:
      of MeritStatus.Unlocked:
        #[
        Their Merit becomes locked if it's been a complete Checkpoint period.
        This doesn't mean 5 Blocks; it means a whole unique period.
        ]#
        var blocksOfInactivity: int = 10 - (state.lastParticipation[h] mod 5)
        #[
        If a Merit Holder participated in Block 5, which created a Checkpoint,
        and Block 10 passes, that'a difference of 5 and an entire period of inactivity.
        We could also use a mod 5 + 5, but this is cleaner.
        ]#
        if blocksOfInactivity == 10:
          blocksOfInactivity = 5

        #If the Merit Holder is inactive, lock their Merit.
        if state.processedBlocks - state.lastParticipation[h] == blocksOfInactivity:
          state.unlocked -= state.merit[h]
          state.statuses[h] = MeritStatus.Locked
          state.db.saveMeritStatus(uint16(h), int(state.statuses[h]))

      of MeritStatus.Locked:
        #Move their Merit to Pending if they had an Element archived.
        if participants.contains(uint16(h)):
          state.statuses[h] = MeritStatus.Pending
          state.db.saveMeritStatus(uint16(h), int(state.statuses[h]))
          state.unlocked += state.merit[h]
          #Set the lastParticipation Block to when their Merit should become unlocked again.
          state.lastParticipation[h] = state.processedBlocks + (10 - (state.processedBlocks mod 5))
          state.db.saveLastParticipation(uint16(h), state.lastParticipation[h])

      of MeritStatus.Pending:
        #If the current Block is their Block of lastParticipation, their buffer period is over.
        #That means their Merit becomes Unlocked.
        if state.lastParticipation[h] == state.processedBlocks:
          state.statuses[h] = MeritStatus.Unlocked
          state.db.saveMeritStatus(uint16(h), int(state.statuses[h]))

  #Save the amount of Unlocked Merit for the next Block.
  #This will be overwritten when we process the next Block, yet is needed for some statuses.
  state.saveUnlocked()

#Calculate the Verification threshold for an Epoch that ends on the specified Block.
proc protocolThresholdAt*(
  state: State,
  height: int
): int {.inline, forceCheck: [].} =
  state.loadUnlocked(height) div 2 + 1

#[
Calculate the threshold for an Epoch that ends on the specified Block.
This is meant to return 80% of the amount of Merit at the time of finalization.
Thanks to truncation, it returns 55% in the worst case scenario (9).
Anything below 5 would return 1, which is 25%, hence the max.
]#
proc nodeThresholdAt*(
  state: State,
  height: int
): int {.inline, forceCheck: [].} =
  (max(state.loadUnlocked(height), 5) div 5 * 4) + 1

proc revert*(
  state: var State,
  blockchain: Blockchain,
  height: int
) {.forceCheck: [].} =
  #Mark the State as working with old data.
  state.oldData = true

  for i in countdown(state.processedBlocks - 1, height):
    var
      #Nickname of the miner we're handling.
      nick: uint16
      #Block we're reverting past.
      revertingPast: Block
    try:
      revertingPast = blockchain[i]
    except IndexError as e:
      panic("Couldn't get the Block to revert past: " & e.msg)

    #Restore removed Merit.
    for removal in state.loadBlockRemovals(i):
      state[removal.nick] = removal.merit

    #Grab the miner's nickname.
    nick = state.getNickname(revertingPast)

    #Remove the Merit rewarded by the Block we just reverted past.
    state[nick] = state.merit[int(nick)] - 1

    #If the miner was new to this Block, remove their nickname.
    if revertingPast.header.newMiner:
      state.deleteLastNickname()

    #If i is over the dead blocks quantity, meaning there is a historical Block to add back to the State...
    if i > state.deadBlocks:
      #Get the miner for said historical Block.
      try:
        nick = state.getNickname(blockchain[i - state.deadBlocks])
      except IndexError as e:
        panic("State couldn't get a historical Block being revived into the State: " & e.msg)

      #Don't add Merit if the miner had a MeritRemoval.
      var removed: bool = false
      for removal in state.loadHolderRemovals(nick):
        if (removal >= i - state.deadBlocks) and (removal < height):
          removed = true
          break

      #Add back the Merit which died.
      if not removed:
        state[nick] = state.merit[int(nick)] + 1

    #Increment the amount of processed Blocks.
    dec(state.processedBlocks)

  state.oldData = false

  #Regenerate the pending removals cache.
  state.pendingRemovals = initDeque[int]()
  for _ in 0 ..< 6:
    state.cacheNextRemoval(blockchain, height)
