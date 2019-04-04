#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BLS lib.
import ../../../lib/BLS

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Finals lib.
import finals

#Tables standard lib.
import tables

#State object.
finalsd:
    type State* = ref object of RootObj
        #DB.
        db: DatabaseFunctionBox
        #String of every holder.
        holdersStr: string
        #List of unsaved accounts.
        pending: seq[string]

        #Blocks until Merit is dead.
        deadBlocks* {.final.}: uint
        #Live Merit.
        live: uint
        #Address -> Merit
        holders: TableRef[string, uint]

#Constructor.
proc newState*(
    db: DatabaseFunctionBox,
    deadBlocks: uint
): State {.raises: [].} =
    result = State(
        db: db,
        pending: @[],

        deadBlocks: deadBlocks,
        live: 0,
        holders: newTable[string, uint]()
    )
    result.ffinalizeDeadBlocks()

    #Load the live Merit from the DB.
    try:
        result.live = uint(result.db.get("merit_live").fromBinary())
    #If the live merit doesn't exist, carry on.
    except:
        discard

    #Load the state, if one exists.
    try:
        #Grab the Merit holders.
        result.holdersStr = result.db.get("merit_holders")

        for i in countup(0, result.holdersStr.len - 1, 48):
            #Extract the holder.
            var holder = result.holdersStr[i .. i + 47]

            #Load their balance.
            result.holders[holder] = uint(result.db.get("merit_" & holder).fromBinary())
    except:
        result.holdersStr = ""

#Add a Holder to the State.
proc add(state: State, key: string) {.raises: [].} =
    #Return if they are already in the state.
    if state.holders.hasKey(key):
        return

    #Add them to the table.
    state.holders[key] = 0

    #Add them to the holders' string.
    state.holdersStr &= key

#Getters.
#Provides read only access to the holder string, which is also used to regenerate the Epochs.
proc `holdersStr`*(state: State): string {.raises: [].} =
    state.holdersStr

proc `[]`*(state: State, keyArg: string): uint {.raises: [KeyError].} =
    #Make sure the key is padded.
    var key: string = keyArg.pad(48)

    #Add this holder to the State if they don't exist already.
    state.add(key)

    #Return their value.
    result = state.holders[key]

proc `[]`*(state: State, key: BLSPublicKey): uint {.inline, raises: [KeyError].} =
    state[key.toString()]

#Return the amount of live Merit.
proc `live`*(state: State): uint {.raises: [].} =
    state.live

#Setters.
proc `[]=`*(state: State, keyArg: string, value: uint) {.raises: [KeyError].} =
    #Extract the argument.
    var key: string = keyArg.pad(48)

    #Get the previous value (uses the State `[]` so `add` is called).
    var previous: uint = state[key]
    #Set their new value.
    state.holders[key] = value
    #Update live accrodingly.
    if value > previous:
        state.live += value - previous
    else:
        state.live -= previous - value

    #Mark them as pending to be saved.
    state.pending.add(key)

proc `[]=`*(state: State, key: BLSPublicKey, value: uint) {.inline, raises: [KeyError].} =
    state[key.toString()] = value

#Save the State to the DB.
proc save*(state: State) {.raises: [KeyError, LMDBError].} =
    #Iterate over every pending account.
    for key in state.pending:
        #Save the new balance to the DB.
        state.db.put("merit_" & key, state.holders[key].toBinary())

    #Clear pending.
    state.pending = @[]

    #Save the new Merit quantity.
    state.db.put("merit_live", state.live.toBinary())

    #Save the holdersStr.
    state.db.put("merit_holders", state.holdersStr)
