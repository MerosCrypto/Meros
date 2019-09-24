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

#Finals lib.
import finals

#Tables standard lib.
import tables

#State object.
finalsd:
    #This cannot be a ref object due to how we copy it for reversions.
    type State* = object
        #DB.
        db: DB
        #Reverting/Catching up.
        oldData*: bool

        #Blocks until Merit is dead.
        deadBlocks* {.final.}: int
        #Live Merit.
        live: int

        #Amount of Blocks processed.
        processedBlocks*: int

        #List of holders. Position on the list is their nickname.
        holders: seq[BLSPublicKey]
        #Nickname -> Merit
        merit: Table[int, int]
        #Removed MeritHolders.
        removed: Table[int, int]

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
        live: 0,

        processedBlocks: blockchainHeight,

        holders: @[],
        merit: initTable[int, int](),
        removed: initTable[int, int]()
    )
    result.ffinalizeDeadBlocks()

    #Load the amount of Live Merit.
    try:
        result.live = result.db.loadLive(result.processedBlocks)
    except DBReadError:
        discard

    #Load the holders.
    result.holders = result.db.loadHolders()
    for h in 0 ..< result.holders.len:
        try:
            result.merit[h] = result.db.loadMerit(h)
        except DBReadError as e:
            doAssert(false, "Couldn't load a holder's Merit: " & e.msg)

#Save the live Merit.
proc saveLive*(
    state: State
) {.inline, forceCheck: [].} =
    state.db.saveLive(state.processedBlocks - 1, state.live)

#Getters.
#Return the amount of live Merit.
func live*(
    state: State
): int {.inline, forceCheck: [].} =
    state.live

proc loadLive*(
    state: State,
    blockNum: int
): int {.forceCheck: [].} =
    #If the Block is in the future, return the amount it will be (without Merit Removals).
    if blockNum >= state.processedBlocks:
        result = min(
            ((blockNum - state.processedBlocks) * 100) + state.live,
            state.deadBlocks * 100
        )
    #Load the amount of live Merit at the specified Block.
    else:
        try:
            result = state.db.loadLive(blockNum)
        except DBReadError:
            doAssert(false, "Couldn't load the live Merit for a Block below the `processedBlocks`.")

#Register a new Merit Holder.
proc newHolder*(
    state: var State,
    holder: BLSPublicKey
): int {.forceCheck: [].} =
    result = state.holders.len
    state.holders.add(holder)
    state.db.saveHolder(holder)

#Get a Merit Holder's Merit.
proc `[]`*(
    state: var State,
    nick: int
): int {.forceCheck: [].} =
    #Return their value.
    if nick >= state.holders.len:
        return 0

    try:
        result = state.merit[nick]
    except KeyError as e:
        doAssert(false, "State threw a KeyError when getting a value, despite checking the nick was in bounds: " & e.msg)

#Get the removals from a Block.
proc loadBlockRemovals*(
    state: State,
    blockNum: int
): seq[tuple[nick: int, merit: int]] {.inline, forceCheck: [].} =
    state.db.loadBlockRemovals(blockNum)

#Get the removals for a holder.
proc loadHolderRemovals*(
    state: State,
    nick: int
): seq[int] {.inline, forceCheck: [].} =
    state.db.loadHolderRemovals(nick)

#Setters.
proc `[]=`*(
    state: var State,
    nick: int,
    value: int
) {.inline, forceCheck: [].} =
    #Get the current value.
    var current: int = state[nick]
    #Set their new value.
    state.merit[nick] = value
    #Update live accrodingly.
    if value > current:
        state.live += value - current
    else:
        state.live -= current - value

    #Save the updated values.
    if not state.oldData:
        state.db.saveMerit(nick, value)

#Remove a MeritHolder's Merit.
proc removeInternal*(
    state: var State,
    nick: int,
    nonce: int
) {.forceCheck: [].} =
    state.db.remove(nick, state[nick], nonce)
    state[nick] = 0
    state.db.saveLive(state.processedBlocks, state.live)

#Reverse lookup for a key to nickname.
proc reverseLookup*(
    state: State,
    key: BLSPublicKey
): int {.forceCheck: [
    IndexError
].} =
    try:
        result = state.db.loadNickname(key)
    except DBReadError:
        raise newException(IndexError, $key & " does not have a nickname.")

#Access the holders.
proc holders*(
    state: State
): seq[BLSPublicKey] {.forceCheck: [].} =
    state.holders
