#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#MinerWallet lib (for BLSPublicKey).
import ../../../Wallet/MinerWallet

#Merit DB lib.
import ../../Filesystem/DB/MeritDB

#Miners and Block objects.
import MinersObj
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
        holders: Table[string, int]

        #Removed MeritHolders.
        removed: Table[string, int]

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
        holders: initTable[string, int](),

        removed: initTable[string, int]()
    )
    result.ffinalizeDeadBlocks()

    #Load the live Merit and the holders from the DB.
    var holders: seq[string]
    try:
        result.live = result.db.loadLiveMerit()
        holders = result.db.loadHolders()
    #If these don't exist, confirm we didn't load one but not the other.
    except DBReadError:
        if result.live != 0:
            doAssert(false, "Loaded the amount of live Merit but not the amount of processed blocks or any holders from the database.")

    #Handle each holder.
    for holder in holders:
        #Load their balance.
        try:
            result.holders[holder] = result.db.loadMerit(holder)
        except DBReadError as e:
            doAssert(false, "Couldn't load a holder's Merit: " & e.msg)

#Add a Holder to the State.
proc add(
    state: var State,
    key: string
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
proc `[]`*(
    state: var State,
    key: string
): int {.forceCheck: [].} =
    #Add this holder to the State if they don't exist already.
    state.add(key)

    #Return their value.
    try:
        result = state.holders[key]
    except KeyError as e:
        doAssert(false, "State threw a KeyError when getting a value, despite calling add before attempting." & e.msg)

proc `[]`*(
    state: var State,
    key: BLSPublicKey
): int {.inline, forceCheck: [].} =
    state[key.toString()]

#Return the amount of live Merit.
func live*(
    state: State
): int {.inline, forceCheck: [].} =
    state.live

#Get the removals from a Block.
proc loadRemovals*(
    state: State,
    blockNum: int
): seq[tuple[key: BLSPublicKey, merit: int]] {.forceCheck: [].} =
    var removals: string
    try:
        removals = state.db.loadRemovals(blockNum)
    except DBReadError:
        return

    for i in countup(0, removals.len - 1, 52):
        try:
            result.add(
                (
                    key: newBLSPublicKey(removals[i * 52 ..< (i * 52) + 48]),
                    merit: removals[(i * 52) + 48 ..< (i * 52) + 52].fromBinary()
                )
            )
        except BLSError as e:
            doAssert(false, "Saved an invalid BLS key to the Database: " & e.msg)

#Get the removals for a holder.
proc loadRemovals*(
    state: State,
    holder: BLSPublicKey
): seq[int] {.forceCheck: [].} =
    var removals: string
    try:
        removals = state.db.loadRemovals(holder)
    except DBReadError:
        return

    for i in countup(0, removals.len - 1, 4):
        result.add(removals[i ..< i + 4].fromBinary())

#Setters.
proc `[]=`*(
    state: var State,
    key: string,
    value: int
) {.forceCheck: [].} =
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
        state.db.saveLiveMerit(state.live)

proc `[]=`*(
    state: var State,
    key: BLSPublicKey,
    value: int
) {.inline, forceCheck: [].} =
    state[key.toString()] = value

#Remove a MeritHolder's Merit.
proc removeInternal*(
    state: var State,
    key: BLSPublicKey,
    archiving: Block
) {.forceCheck: [].} =
    state.db.remove(key.toString(), state[key], archiving.nonce)
    state[key] = 0

#Iterator for every holder.
iterator holders*(
    state: State
): string {.forceCheck: [].} =
    for holder in state.holders.keys():
        yield holder
