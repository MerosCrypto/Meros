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
        #Seq of every holder.
        holdersSeq: seq[string]
        #String of every holder.
        holdersStr: string

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
): State {.raises: [LMDBError].} =
    result = State(
        db: db,
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

        #Parse them into the seq.
        result.holdersSeq = newSeq[string](result.holdersStr.len div 48)

        for i in countup(0, result.holdersStr.len, 48):
            #Extract the holder.
            var holder = result.holdersStr[i .. i + 47]

            #Add it to the seq.
            result.holdersSeq[i div 48] = holder

            #Load their balance.
            result.holders[holder] = uint(result.db.get("merit_" & holder).fromBinary())
    except:
        result.holdersStr = ""
        result.holdersSeq = @[]

#Add a Holder to the State.
proc add(state: State, key: string, save: bool) {.raises: [].} =
    #Return if they are already in the state.
    if state.holders.hasKey(key):
        return

    #Add them to the table.
    state.holders[key] = 0

    #We don't save gets so we don't have bubble up LMDBErrors everywhere.
    #If this is setting the value, add it to the holders data.
    #The set itself will enter it into the DB.
    if save:
        #Add them to the seq and str
        state.holdersSeq.add(key)
        state.holdersStr &= key

#Getters.
proc `[]`*(state: State, key: string): uint {.raises: [KeyError].} =
    #Add this holder to the State if they don't exist already.
    state.add(key, false)

    #Return their value.
    result = state.holders[key]

proc `[]`*(state: State, keyArg: BLSPublicKey): uint {.raises: [KeyError].} =
    #Extract the argument.
    var key: string = keyArg.toString()

    #Add this holder to the State if they don't exist already.
    state.add(key, false)

    #Return their value.
    result = state.holders[key]

#Return the amount of live Merit.
proc `live`*(state: State): uint {.raises: [].} =
    state.live

#Setter.
proc `[]=`*(state: State, keyArg: string, value: uint) {.raises: [KeyError, LMDBError].} =
    #Extract the argument.
    var key: string = keyArg.pad(48)

    #Add this holder to the State if they don't exist already.
    state.add(key, true)

    #Get the previous value.
    var previous: uint = state.holders[key]
    #Set their new value.
    state.holders[key] = value
    #Update live accrodingly.
    if value > previous:
        state.live += value - previous
    else:
        state.live -= previous - value

    #Save the new balance to the DB.
    state.db.put("merit_" & key, value.toBinary())

    #Save the new updated merit value.
    state.db.put("merit_live", state.live.toBinary())
