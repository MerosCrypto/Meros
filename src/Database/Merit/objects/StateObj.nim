import deques

import ../../../lib/[Errors, Util]
import ../../../Wallet/MinerWallet

import ../../Filesystem/DB/MeritDB

import BlockObj

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
    unlocked*: int

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

    pendingRemovals*: Deque[int]

proc newStateObj*(
  db: DB,
  deadBlocks: int,
  blockchainHeight: int
): State {.forceCheck: [].} =
  result = State(
    db: db,
    oldData: false,

    deadBlocks: deadBlocks,
    unlocked: 0,

    processedBlocks: blockchainHeight,

    pendingRemovals: initDeque[int](8)
  )

  #Load the amount of Unlocked Merit.
  try:
    result.unlocked = result.db.loadUnlocked(result.processedBlocks - 1)
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
      result.statuses[h] = MeritStatus(result.db.loadMeritStatus(uint16(h)))
      result.lastParticipation[h] = result.db.loadLastParticipation(uint16(h))
    except DBReadError as e:
      panic("Couldn't load a holder's Merit: " & e.msg)

proc saveUnlocked*(
  state: State
) {.inline, forceCheck: [].} =
  state.db.saveUnlocked(state.processedBlocks - 1, state.unlocked)

proc loadUnlocked*(
  state: State,
  height: int,
): int {.forceCheck: [].} =
  #If the Block is in the future, return the amount it will be (without Merit Removals).
  if height >= state.processedBlocks:
    result = min(
      (height - state.processedBlocks) + state.unlocked,
      state.deadBlocks
    )
  #Load the amount of Unlocked Merit at the specified Block.
  else:
    try:
      result = state.db.loadUnlocked(height - 1)
    except DBReadError:
      panic("Couldn't load the Unlocked Merit for a Block below the `processedBlocks`.")

#Register a new Merit Holder.
proc newHolder*(
  state: var State,
  nick: uint16
) {.forceCheck: [].} =
  if int(nick) == state.merit.len:
    state.merit.setLen(int(nick) + 1)
    state.statuses.setLen(int(nick) + 1)
    state.lastParticipation.setLen(int(nick) + 1)

  state.merit[int(nick)] = 0
  state.statuses[int(nick)] = MeritStatus.Unlocked
  state.lastParticipation[int(nick)] = state.processedBlocks + (5 - ((state.processedBlocks + 1) mod 5))

  state.db.saveMeritStatus(nick, int(state.statuses[int(nick)]))
  state.db.saveLastParticipation(nick, state.lastParticipation[int(nick)])

proc newHolder*(
  state: var State,
  holder: BLSPublicKey
): uint16 {.forceCheck: [].} =
  result = uint16(state.holders.len)
  state.holders.add(holder)
  state.db.saveHolder(holder)
  state.newHolder(result)

#Get a Merit Holder's Merit.
proc `[]`*(
  state: State,
  nick: uint16,
  height: int
): int {.forceCheck: [].} =
  #If the nick is out of bounds, yet still positive, return 0.
  if nick >= uint16(state.holders.len):
    return 0

  #If the Merit is locked, report it as non-existent.
  if state.statuses[int(nick)] == MeritStatus.Locked:
    return 0

  result = state.merit[int(nick)]

  #Iterate over the pending removal cache, seeing if we need to decrement at all.
  for r in 0 ..< height - state.processedBlocks:
    try:
      if state.pendingRemovals[r] == int(nick):
        dec(result)
    except IndexError as e:
      panic("Couldn't get a pending Dead Merit removal: " & e.msg)

  #If their Merit is pending, return 0 if it won't be unlocked by the specified height.
  if (
    (state.statuses[int(nick)] == MeritStatus.Pending) and
    (height < state.lastParticipation[int(nick)])
  ):
    return 0

proc loadBlockRemovals*(
  state: State,
  blockNum: int
): seq[tuple[nick: uint16, merit: int]] {.inline, forceCheck: [].} =
  state.db.loadBlockRemovals(blockNum)

proc loadHolderRemovals*(
  state: State,
  nick: uint16
): seq[int] {.inline, forceCheck: [].} =
  state.db.loadHolderRemovals(nick)

#Set a holder's Merit.
proc `[]=`*(
  state: var State,
  nick: uint16,
  value: int
) {.inline, forceCheck: [].} =
  #Get the current value.
  var current: int = state[nick, state.processedBlocks]
  #Set their new value.
  state.merit[int(nick)] = value
  #Update unlocked accrodingly.
  if value > current:
    state.unlocked += value - current
  else:
    state.unlocked -= current - value

  #Save the updated values.
  if not state.oldData:
    state.db.saveMerit(nick, value)

#Remove a MeritHolder's Merit.
proc remove*(
  state: var State,
  nick: uint16,
  nonce: int
) {.forceCheck: [].} =
  state.db.remove(nick, state[nick, state.processedBlocks], nonce)
  state[nick] = 0
  state.db.saveUnlocked(state.processedBlocks, state.unlocked)

  try:
    for p in 0 ..< state.pendingRemovals.len:
      if state.pendingRemovals[p] == int(nick):
        state.pendingRemovals[p] = -1
  except IndexError as e:
    panic("Couldn't remove the Dead Merit removal for a Merit Holder who had a MeritRemoval: " & e.msg)

#Delete the last nickname from RAM.
proc deleteLastNickname*(
  state: var State
) {.inline, forceCheck: [].} =
  state.holders.del(high(state.holders))

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
