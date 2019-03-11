#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#BLS lib.
import ../../lib/BLS

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#Miners object.
import objects/MinersObj

#Block and Blockchain libs.
import Block
import Blockchain

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
        live*: uint
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
    #If the live merit doesn't exist, add one.
    except:
        result.db.put("merit_live", result.live.toBinary())

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

#Get the Merit of an account.
func getBalance*(state: State, account: BLSPublicKey): uint {.raises: [KeyError].} =
    #Set the result to 0 (in case there isn't an entry in the table).
    result = 0

    #If there is an entry, set the result to it.
    if state.holders.hasKey(account.toString()):
        result = state.holders[account.toString()]

#Process a block.
proc processBlock*(
    state: State,
    blockchain: Blockchain,
    newBlock: Block
) {.raises: [
    KeyError,
    ValueError,
    ArgonError,
    BLSError,
    LMDBError,
    FinalAttributeError
].} =
    #Grab the miners.
    var miners: Miners = newBlock.miners

    #For each miner, add their Merit to the State.
    for miner in miners:
        state.holders[miner.miner.toString()] = state.getBalance(miner.miner) + miner.amount
        state.live += miner.amount

    #If the Blockchain's height is over 50k, meaning there is a block to remove from the state...
    if blockchain.height > state.deadBlocks:
        #Get the block that should be removed.
        miners = blockchain[blockchain.height - (state.deadBlocks + 1)].miners
        #For each miner, remove their Merit from the State.
        for miner in miners:
            state.holders[miner.miner.toString()] = state.getBalance(miner.miner) - miner.amount
            state.live -= miner.amount
