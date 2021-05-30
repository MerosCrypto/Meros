import deques

#Hash is imported so we can print them in error messages; not because we mutate or check them.
import ../../lib/[Errors, Hash]
import ../../Wallet/MinerWallet

import ../Filesystem/DB/MeritDB

import objects/BlockchainObj
import BlockHeader, Block

import objects/StateObj
export MeritStatus, StateObj.State, StateChanges, `[]`, reverseLookup, loadCounted

proc getNickname(
  state: var State,
  blockArg: Block,
  newBlock: bool = false,
  callNew: bool = false
): uint16 {.forceCheck: [].} =
  if blockArg.header.newMiner:
    try:
      result = state.reverseLookup(blockArg.header.minerKey)
    except IndexError:
      #Call new is not used here because we always want to create a holder when dealing with a new key.
      if newBlock:
        result = state.newHolder(blockArg.header.minerKey)
        return
      panic($blockArg.header.minerKey & " in Block " & $blockArg.header.hash & " doesn't have a nickname.")
  else:
    result = blockArg.header.minerNick

  #If this a holder with no Merit, who is regaining Merit, re-register them.
  if callNew and (state.merit[result] == 0):
    #Work around for the fact getNickname is called before we increase processedBlocks.
    inc(state.processedBlocks)
    state.newHolder(result)
    dec(state.processedBlocks)

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
      nick = state.getNickname(blockchain[nonce])
    except IndexError as e:
      panic("State tried to remove dead Merit yet couldn't get the old Block: " & e.msg)

    #Do nothing if they had their Merit removed.
    try:
      if state.db.loadRemovalHeight(nick) < height:
        state.pendingRemovals.addLast(-1)
        return
    except DBReadError:
      discard

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
): StateChanges {.forceCheck: [].} =
  logDebug "State processing Block", hash = blockchain.tail.header.hash

  try:
    result.decd = state.pendingRemovals.popFirst()
  except IndexError as e:
    panic("Couldn't pop the pending Dead Merit removal: " & e.msg)

  #Get the next Merit about to die.
  state.cacheNextRemoval(blockchain, blockchain.height)

  #Grab the new Block.
  var newBlock: Block = blockchain.tail

  #Save the Merit amounts.
  state.saveMerits()

  #Add the miner's Merit to the State.
  var nick: uint16 = state.getNickname(newBlock, true, true)
  result.incd = nick
  state[nick] = state.merit[nick] + 1
  inc(state.total)
  if state.statuses[nick] != MeritStatus.Locked:
    inc(state.counted)
    if state.statuses[nick] == MeritStatus.Pending:
      inc(state.pending)

  #If there was a removal, decrement their Merit.
  if result.decd != -1:
    state[uint16(result.decd)] = state.merit[result.decd] - 1
    dec(state.total)
    if state.statuses[uint16(result.decd)] != MeritStatus.Locked:
      dec(state.counted)
      if state.statuses[uint16(result.decd)] == MeritStatus.Pending:
        dec(state.pending)

  #Mark participants to prevent their Merit from being locked.
  var participants: set[uint16]
  for packet in newBlock.body.packets:
    for holder in packet.holders:
      participants.incl(holder)
  for elem in newBlock.body.elements:
    participants.incl(elem.holder)

  #Remove Merit from Merit Holders who had their Merit Removals archived in this Block.
  for holder in newBlock.body.removals:
    logWarn "State removing Merit of malicious holder", holder=holder
    state.remove(holder, blockchain.height - 1)

  #Increment the amount of processed Blocks.
  inc(state.processedBlocks)

  #Update every holder's Merit Status.
  for h in 0 ..< state.statuses.len:
    #Provide a clean status for a Merit Holder whose Merit died.
    if state.merit[h] == 0:
      state.statuses[h] = MeritStatus.Unlocked
      state.db.appendMeritStatus(uint16(h), blockchain.height, byte(state.statuses[h]))
      continue

    if participants.contains(uint16(h)):
      #Use the higher value to handle buffer periods.
      state.lastParticipation[h] = max(state.processedBlocks, state.lastParticipation[h])
      state.db.appendLastParticipation(uint16(h), blockchain.height, state.lastParticipation[h])

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
          logInfo "Locking Merit", holder = h
          state.counted -= state.merit[h]
          state.statuses[h] = MeritStatus.Locked
          state.db.appendMeritStatus(uint16(h), blockchain.height, byte(state.statuses[h]))
          result.locked.add(uint16(h))

      of MeritStatus.Locked:
        #Move their Merit to Pending if they had an Element archived.
        if participants.contains(uint16(h)):
          logInfo "Starting to unlock Merit", holder = h
          state.statuses[h] = MeritStatus.Pending
          state.db.appendMeritStatus(uint16(h), blockchain.height, byte(state.statuses[h]))
          state.pending += state.merit[h]
          #Start requiring a higher threshold now.
          state.counted += state.merit[h]

          #Set the lastParticipation Block to when their Merit should become unlocked again.
          state.lastParticipation[h] = state.processedBlocks + (10 - (state.processedBlocks mod 5))
          state.db.appendLastParticipation(uint16(h), blockchain.height, state.lastParticipation[h])
          result.pending.add(uint16(h))

      of MeritStatus.Pending:
        #If the current Block is their Block of lastParticipation, their buffer period is over.
        #That means their Merit becomes Unlocked.
        if state.lastParticipation[h] == state.processedBlocks:
          logInfo "Unlocking Merit", holder = h
          state.pending -= state.merit[h]
          state.statuses[h] = MeritStatus.Unlocked
          state.db.appendMeritStatus(uint16(h), blockchain.height, byte(state.statuses[h]))

  var
    tCopy = state.total
    cCopy = state.counted
    pCopy = state.pending
  try:
    for h in 0 ..< state.merit.len:
      tCopy -= state.merit[h]
      if state.statuses[h] == MeritStatus.Unlocked:
        cCopy -= state.merit[h]
      if state.statuses[h] == MeritStatus.Pending:
        cCopy -= state.merit[h]
        pCopy -= state.merit[h]
  except Exception as e:
    panic("Exception when checking Merit status of a holder: " & e.msg)
  if tCopy != 0:
    panic("Total is wrong.")
  if cCopy != 0:
    panic("Counted is wrong.")
  if pCopy != 0:
    panic("Pending is wrong.")

  #Save the Merit amounts for the next Block.
  #This will be overwritten when we process the next Block, yet is needed for some statuses.
  state.saveMerits()

#Calculate the Verification threshold for an Epoch that ends on the specified Block.
proc protocolThreshold*(
  state: State
): int {.inline, forceCheck: [].} =
  (
    state.loadCounted(state.processedBlocks) -
    state.loadPending(state.processedBlocks)
  ) div 2 + 1

#[
Calculate the threshold for an Epoch that ends on the specified Block.
This is meant to return 67% of the amount of Merit at the time of finalization.
]#
proc nodeThresholdAt*(
  state: State,
  height: int
): int {.inline, forceCheck: [].} =
  (max(state.loadCounted(height), 5) div 5 * 4) + 1
  #(state.loadCounted(height) * 2 div 3) + 1

proc revert*(
  state: var State,
  blockchain: Blockchain,
  height: int
) {.forceCheck: [].} =
  #Mark the State as working with old data. Prevents writing to the DB.
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
      state.hasMR.excl(removal.nick)

    #Grab the miner's nickname.
    nick = state.getNickname(revertingPast)

    #Remove the Merit rewarded by the Block we just reverted past.
    state[nick] = state.merit[nick] - 1

    #If i is over the dead blocks quantity, meaning there is a historical Block to add back to the State...
    if i > state.deadBlocks:
      #Get the miner for said historical Block.
      try:
        nick = state.getNickname(blockchain[i - state.deadBlocks])
      except IndexError as e:
        panic("State couldn't get a historical Block being revived into the State: " & e.msg)

      #Don't add Merit back if the miner has a MeritRemoval.
      var removed: bool = false
      try:
        removed = state.db.loadRemovalHeight(nick) <= height
      except DBReadError:
        discard
      if not removed:
        #Add back the Merit which died.
        state[nick] = state.merit[nick] + 1

    #If the miner was new to this Block, remove their nickname.
    if revertingPast.header.newMiner:
      state.deleteLastNickname()

  #Reload the old statuses/participations.
  for h in 0 ..< state.holders.len:
    state.statuses[h] = state.findMeritStatus(uint16(h), height)
    state.lastParticipation[h] = state.findLastParticipation(uint16(h), height)

  #Reload the Merit amounts.
  try:
    state.total = state.db.loadTotal(height - 1)
    state.pending = state.db.loadPending(height - 1)
    state.counted = state.db.loadCounted(height - 1)
  except DBReadError as e:
    panic("Couldn't load a historical Merit amount: " & e.msg)

  #Correct the amount of processed Blocks.
  state.processedBlocks = height

  #Regenerate the pending removals cache.
  state.pendingRemovals = initDeque[int]()
  for _ in 0 ..< 6:
    state.cacheNextRemoval(blockchain, state.processedBlocks)

  #Allow saving data again.
  state.oldData = false

proc pruneStatusesAndParticipations*(
  state: State,
  oldAmountOfHolders: int
) {.forceCheck: [].} =
  for h in 0 ..< state.holders.len:
    discard state.findMeritStatus(uint16(h), state.processedBlocks, true)
    discard state.findLastParticipation(uint16(h), state.processedBlocks, true)

  for h in state.holders.len ..< oldAmountOfHolders:
    state.db.overrideMeritStatuses(uint16(h), "")
    state.db.overrideLastParticipations(uint16(h), "")

proc isValidHolderWithMerit*(
  state: State,
  holder: uint16
): bool {.forceCheck: [].} =
  #Verify the holder exists.
  if holder >= uint16(state.holders.len):
    logDebug "Asked if a holder who was never created is valid", holder = holder
    return false
  #Verify they can still participate on this chain.
  elif state.hasMR.contains(holder):
    logDebug "Asked if a holder who had a Merit Removal is valid", holder = holder
    return false
  #Check if they have Merit.
  elif state[holder, state.processedBlocks] == 0:
    logDebug "Asked if a holder who has no Merit is valid", holder = holder
  result = true
