import deques

import ../../../lib/[Errors, Util]
import ../../../Wallet/MinerWallet

import ../../Filesystem/DB/MeritDB

import BlockObj

import ../../../Network/Serialize/SerializeCommon

type
  MeritStatus* = enum
    #Fully usable.
    Unlocked,
    #Not usable, yet allows Elements on the chain.
    Locked,
    #Elements present on the chain, will convert to Unlocked soon.
    Pending

  State* = object
    db*: DB
    #Reverting/Catching up.
    oldData*: bool

    deadBlocks*: int

    total*: int
    pending*: int
    counted*: int

    processedBlocks*: int

    #List of holders. Position on the list is their nickname.
    holders*: seq[BLSPublicKey]
    merit*: seq[int]
    #State of their Merit.
    statuses*: seq[MeritStatus]
    #[
    Block this user last participated int.

    If this user only just got Merit, or only just got their Merit unlocked,
    there is a buffer period for their inactivity.
    Then this is set to when the buffer period is over, to ensure the buffer period is enforced.

    If their Merit is pending, this is set to the Block in which their Merit will unlock.
    This again handles the buffer period.
    ]#
    lastParticipation*: seq[int]

    #Refers to Merit being decremented from dying; not Merit Removals.
    pendingRemovals*: Deque[int]

    #Set of Merit Holders with a Merit Removal, invalidating all future participation.
    hasMR: set[uint16]

  #Object returned after processing a new Block.
  StateChanges* = object
    incd*: uint16
    decd*: int
    locked*: seq[uint16]
    pending*: seq[uint16]

proc newStateObj*(
  db: DB,
  deadBlocks: int,
  blockchainHeight: int
): State {.forceCheck: [].} =
  result = State(
    db: db,
    oldData: false,

    deadBlocks: deadBlocks,

    total: 0,
    pending: 0,
    counted: 0,

    processedBlocks: blockchainHeight,

    pendingRemovals: initDeque[int](8),

    hasMR: {}
  )

  #Load the Merit amounts.
  try:
    result.total = result.db.loadTotal(result.processedBlocks - 1)
    result.pending = result.db.loadPending(result.processedBlocks - 1)
    result.counted = result.db.loadCounted(result.processedBlocks - 1)
  except DBReadError:
    discard

  #Load the holders.
  result.holders = result.db.loadHolders()
  result.merit = newSeq[int](result.holders.len)
  result.statuses = newSeq[MeritStatus](result.holders.len)
  result.lastParticipation = newSeq[int](result.holders.len)
  for h in 0 ..< result.holders.len:
    try:
      result.merit[h] = result.db.loadMerit(uint16(h))
      var statuses: string = result.db.loadMeritStatuses(uint16(h))
      if statuses.len != 0:
        result.statuses[h] = MeritStatus(statuses[^1])
      var lastParticipations: string = result.db.loadLastParticipations(uint16(h))
      result.lastParticipation[h] = lastParticipations[lastParticipations.len - INT_LEN ..< lastParticipations.len].fromBinary()
    except DBReadError as e:
      panic("Couldn't load a holder's Merit: " & e.msg)

  #Load the holders with Merit Removals.
  state.hasMR = result.db.loadHoldersWithRemovals()

proc saveMerits*(
  state: State,
) {.inline, forceCheck: [].} =
  state.db.saveMerits(state.processedBlocks - 1, state.total, state.pending, state.counted)

proc loadCounted*(
  state: State,
  height: int,
): int {.forceCheck: [].} =
  #If the Block is in the future, return the amount it will be (without Merit Removals).
  if height >= state.processedBlocks:
    result = min(
      (height - state.processedBlocks) + state.counted,
      state.deadBlocks
    )
  #Load the amount of counted Merit at the specified Block.
  else:
    try:
      result = state.db.loadCounted(height - 1)
    except DBReadError:
      panic("Couldn't load the Unlocked Merit for a Block below the `processedBlocks`.")

proc loadPending*(
  state: State,
  height: int,
): int {.forceCheck: [].} =
  if height > state.processedBlocks:
    panic("Can't predict the amount of pending Merit.")
  elif height == state.processedBlocks:
    result = state.pending
  else:
    try:
      result = state.db.loadPending(height - 1)
    except DBReadError:
      panic("Couldn't load the Unlocked Merit for a Block below the `processedBlocks`.")

#Register a new Merit Holder.
proc newHolder*(
  state: var State,
  nick: uint16
) {.forceCheck: [].} =
  if int(nick) == state.holders.len:
    state.merit.add(0)
    state.statuses.add(MeritStatus.Unlocked)
    if not state.oldData:
      state.db.saveMerit(nick, 0)
      #Don't bother saving that they're unlocked; any untracked historical state is unlocked.
      #This seems like a micro-optimization, yet saving it was causing DB reversion mismatches.
      #While it shouldn't cause any bugs if left saved, we shouldn't add exceptions to the test.
      #state.db.appendMeritStatus(nick, state.processedBlocks, byte(MeritStatus.Unlocked))

    state.lastParticipation.add(0)

  state.lastParticipation[nick] = state.processedBlocks + (5 - (state.processedBlocks mod 5))
  if not state.oldData:
    state.db.appendLastParticipation(nick, state.processedBlocks, state.lastParticipation[nick])

proc newHolder*(
  state: var State,
  holder: BLSPublicKey
): uint16 {.forceCheck: [].} =
  result = uint16(state.holders.len)
  state.db.saveHolder(holder)
  state.newHolder(result)

  #This is placed here as the other newHolder works off state.holders.len as well.
  state.holders.add(holder)

proc findMeritStatus*(
  state: State,
  nick: uint16,
  height: int,
  prune: bool = false
): MeritStatus {.forceCheck: [].} =
  if (not prune) and (height == state.processedBlocks):
    return state.statuses[int(nick)]

  const VALUE_LEN: int = INT_LEN + BYTE_LEN
  var statuses: string = state.db.loadMeritStatuses(nick)
  while statuses.len != 0:
    var valueHeight: int = statuses[statuses.len - VALUE_LEN ..< statuses.len - BYTE_LEN].fromBinary()
    result = MeritStatus(statuses[^1])
    if valueHeight <= height:
      break
    else:
      statuses.setLen(statuses.len - VALUE_LEN)

  #If we never found a result, return a default value.
  #Useful for when the Consensus checks historical Merit, as well as the RPC.
  if statuses.len == 0:
    result = MeritStatus.Unlocked

  if prune:
    state.db.overrideMeritStatuses(nick, statuses)

proc findLastParticipation*(
  state: State,
  nick: uint16,
  height: int,
  prune: bool = false
): int {.forceCheck: [].} =
  if (not prune) and (height == state.processedBlocks):
    return state.lastParticipation[int(nick)]

  const VALUE_LEN: int = INT_LEN + INT_LEN
  var participations: string = state.db.loadLastParticipations(nick)
  while participations.len != 0:
    var valueHeight: int = participations[participations.len - VALUE_LEN ..< participations.len - INT_LEN].fromBinary()
    result = participations[participations.len - INT_LEN ..< participations.len].fromBinary()
    if valueHeight <= height:
      break
    else:
      participations.setLen(participations.len - VALUE_LEN)

  if participations.len == 0:
    result = 0

  if prune:
    state.db.overrideLastParticipations(nick, participations)

#Get a Merit Holder's Merit.
proc `[]`*(
  state: State,
  nick: uint16,
  height: int
): int {.forceCheck: [].} =
  #[
  If the nick is out of bounds, yet still positive, return 0.
  This should only happen with the RPC, and even then, as we can't get the key, it should error.
  That said, there may be some kinks with reversions/reorgs which cause this?
  Since those features work, and this would require a lot of testing to see if it can be removed...
  Just leave it in.
  ]#
  if nick >= uint16(state.holders.len):
    return 0

  #Grab their status at the specified height.
  var statusAtHeight: MeritStatus = state.findMeritStatus(nick, height)
  if (
    #If the Merit is locked, don't count it.
    (statusAtHeight == MeritStatus.Locked) or
    #If the Merit is pending, there's two cases in which it shouldn't be counted.
    (statusAtHeight == MeritStatus.Pending) and (
      #If we're asking for a historical Block, which means it was pending at the time.
      (height <= state.processedBlocks) or
      #If we're asking for a future Block, but it's still in the buffer period waiting to become Unlocked.
      ((height > state.processedBlocks) and ((height < state.lastParticipation[nick])))
    )
  ):
    return 0

  #Grab the raw Merit value.
  result = state.merit[nick]
  #Iterate over the pending removal cache, seeing if we need to decrement at all.
  for r in 0 ..< height - state.processedBlocks:
    try:
      if state.pendingRemovals[r] == int(nick):
        dec(result)
    except IndexError as e:
      panic("Couldn't get a pending Dead Merit removal: " & e.msg)

proc loadBlockRemovals*(
  state: State,
  blockNum: int
): seq[tuple[nick: uint16, merit: int]] {.inline, forceCheck: [].} =
  state.db.loadBlockRemovals(blockNum)

#Set a holder's Merit.
proc `[]=`*(
  state: var State,
  nick: uint16,
  value: int
) {.forceCheck: [].} =
  state.merit[nick] = value
  if not state.oldData:
    state.db.saveMerit(nick, value)

#Remove a MeritHolder's Merit.
proc remove*(
  state: var State,
  nick: uint16,
  nonce: int
) {.forceCheck: [].} =
  state.db.remove(nick, state.merit[nick], nonce)

  state.total -= state.merit[nick]
  if state.statuses[nick] != MeritStatus.Locked:
    state.counted -= state.merit[nick]
    if state.statuses[nick] == MeritStatus.Pending:
      state.pending -= state.merit[nick]
  state.db.saveMerits(state.processedBlocks, state.total, state.pending, state.counted)
  state[nick] = 0

  try:
    for p in 0 ..< state.pendingRemovals.len:
      if state.pendingRemovals[p] == int(nick):
        state.pendingRemovals[p] = -1
  except IndexError as e:
    panic("Couldn't remove the Dead Merit removal for a Merit Holder who had a MeritRemoval: " & e.msg)

  state.hasMR.incl(nick)

#Delete the last nickname from RAM.
proc deleteLastNickname*(
  state: var State
) {.forceCheck: [].} =
  var nick: int = high(state.holders)
  state.holders.del(nick)
  state.merit.del(nick)
  state.statuses.del(nick)
  state.lastParticipation.del(nick)

#Reverse lookup for a key to nickname.
proc reverseLookup*(
  state: State,
  key: BLSPublicKey
): uint16 {.forceCheck: [
  IndexError
].} =
  try:
    result = state.db.loadNickname(key)
  except DBReadError:
    raise newLoggedException(IndexError, $key & " does not have a nickname.")
