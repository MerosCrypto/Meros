#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Merit DB lib.
import ../../Filesystem/DB/MeritDB

#Block object.
import BlockObj

#Tables standard lib.
import tables

#State object.
type State* = object
    #DB.
    db: DB
    #Reverting/Catching up.
    oldData*: bool

    #Blocks until Merit is dead.
    deadBlocks*: int
    #Unlocked Merit.
    unlocked: int

    #Amount of Blocks processed.
    processedBlocks*: int

    #List of holders. Position on the list is their nickname.
    holders: seq[BLSPublicKey]
    #Nickname -> Merit
    merit: Table[uint16, int]

    #Pending removals.
    pendingRemovals*: seq[int]

#Constructor.
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

        holders: @[],
        merit: initTable[uint16, int](),

        pendingRemovals: @[]
    )

    #Load the amount of Unlocked Merit.
    try:
        result.unlocked = result.db.loadUnlocked(result.processedBlocks - 1)
    except DBReadError:
        discard

    #Load the holders.
    result.holders = result.db.loadHolders()
    for h in 0 ..< result.holders.len:
        try:
            result.merit[uint16(h)] = result.db.loadMerit(uint16(h))
        except DBReadError as e:
            panic("Couldn't load a holder's Merit: " & e.msg)

#Save the Unlocked Merit.
proc saveUnlocked*(
    state: State
) {.inline, forceCheck: [].} =
    state.db.saveUnlocked(state.processedBlocks - 1, state.unlocked)

#Getters.
#Return the amount of Unlocked Merit.
func unlocked*(
    state: State
): int {.inline, forceCheck: [].} =
    state.unlocked

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
    holder: BLSPublicKey
): uint16 {.forceCheck: [].} =
    result = uint16(state.holders.len)
    state.merit[result] = 0
    state.holders.add(holder)
    state.db.saveHolder(holder)

#Get a Merit Holder's Merit.
proc `[]`*(
    state: State,
    nick: uint16,
    height: int
): int {.forceCheck: [].} =
    #Throw a fatal error if the nickname is invalid.
    if nick < 0:
        panic("Asking for the Merit of an invalid nickname.")

    #If the nick is out of bounds, yet still positive, return 0.
    if nick >= uint16(state.holders.len):
        return 0

    #Set the Merit to the result.
    try:
        result = state.merit[nick]
    except KeyError as e:
        panic("State threw a KeyError when getting a value, despite checking the nick was in bounds: " & e.msg)

    #Iterate over the pending removal cache, seeing if we need to decrement at all.
    for r in 0 ..< height - state.processedBlocks:
        if state.pendingRemovals[r] == int(nick):
            dec(result)

#Get the removals from a Block.
proc loadBlockRemovals*(
    state: State,
    blockNum: int
): seq[tuple[nick: uint16, merit: int]] {.inline, forceCheck: [].} =
    state.db.loadBlockRemovals(blockNum)

#Get the removals for a holder.
proc loadHolderRemovals*(
    state: State,
    nick: uint16
): seq[int] {.inline, forceCheck: [].} =
    state.db.loadHolderRemovals(nick)

#Setters.
proc `[]=`*(
    state: var State,
    nick: uint16,
    value: int
) {.inline, forceCheck: [].} =
    #Get the current value.
    var current: int = state[nick, state.processedBlocks]
    #Set their new value.
    state.merit[nick] = value
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

    for p in 0 ..< state.pendingRemovals.len:
        if state.pendingRemovals[p] == int(nick):
            state.pendingRemovals[p] = -1

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

#Access the holders.
proc holders*(
    state: State
): seq[BLSPublicKey] {.inline, forceCheck: [].} =
    state.holders
