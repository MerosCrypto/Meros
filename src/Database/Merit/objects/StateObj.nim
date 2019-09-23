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
        #BLSPublicKey -> Merit
        holders: Table[BLSPublicKey, int]

        #Removed MeritHolders.
        removed: Table[BLSPublicKey, int]

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
        holders: initTable[BLSPublicKey, int](),

        removed: initTable[BLSPublicKey, int]()
    )
    result.ffinalizeDeadBlocks()

    #Load the holders and live Merit from the DB.
    var holders: seq[BLSPublicKey] = result.db.loadHolders()
    try:
        result.live = result.db.loadLive(result.processedBlocks)
    except DBReadError:
        discard

    #Handle each holder.
    for holder in holders:
        #Load their balance.
        try:
            result.holders[holder] = result.db.loadMerit(holder)
        except DBReadError as e:
            doAssert(false, "Couldn't load a holder's Merit: " & e.msg)

#Save the live Merit.
proc saveLive*(
    state: State
) {.inline, forceCheck: [].} =
    state.db.saveLive(state.processedBlocks - 1, state.live)

#Add a Holder to the State.
proc add(
    state: var State,
    key: BLSPublicKey
) {.forceCheck: [].} =
    #Return if they are already in the state.
    if state.holders.hasKey(key):
        return

    #Add them to the table.
    state.holders[key] = 0

    #Only save them if this is new data.
    if not state.oldData:
        state.db.save(key, 0)

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
    if blockNum >= state.processedBlocks:
        result = min(
            ((blockNum - state.processedBlocks) * 100) + state.live,
            state.deadBlocks * 100
        )
    else:
        try:
            result = state.db.loadLive(blockNum)
        except DBReadError:
            doAssert(false, "Couldn't load the live Merit for a Block below the `processedBlocks`.")

#Get an Merit Holder's Merit.
proc `[]`*(
    state: var State,
    key: BLSPublicKey
): int {.inline, forceCheck: [].} =
    #Add this holder to the State if they don't exist already.
    state.add(key)

    #Return their value.
    try:
        result = state.holders[key]
    except KeyError as e:
        doAssert(false, "State threw a KeyError when getting a value, despite calling add before attempting." & e.msg)

#Get the removals from a Block.
proc loadRemovals*(
    state: State,
    blockNum: int
): seq[tuple[key: BLSPublicKey, merit: int]] {.inline, forceCheck: [].} =
    state.db.loadRemovals(blockNum)

#Get the removals for a holder.
proc loadRemovals*(
    state: State,
    holder: BLSPublicKey
): seq[int] {.inline, forceCheck: [].} =
    state.db.loadRemovals(holder)

#Setters.
proc `[]=`*(
    state: var State,
    key: BLSPublicKey,
    value: int
) {.inline, forceCheck: [].} =
    #Get the previous value (uses the State `[]` so `add` is called).
    var previous: int = state[key]
    #Set their new value.
    state.holders[key] = value
    #Update live accrodingly.
    if value > previous:
        state.live += value - previous
    else:
        state.live -= previous - value

    #Save the updated values.
    if not state.oldData:
        state.db.save(key, value)

#Remove a MeritHolder's Merit.
proc removeInternal*(
    state: var State,
    key: BLSPublicKey,
    archiving: Block
) {.forceCheck: [].} =
    state.db.remove(key, state[key], archiving.nonce)
    state[key] = 0
    state.db.saveLive(state.processedBlocks, state.live)

#Iterator for every holder.
iterator holders*(
    state: State
): BLSPublicKey {.forceCheck: [].} =
    for holder in state.holders.keys():
        yield holder
