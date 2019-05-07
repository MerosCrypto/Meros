#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Difficulty, Miners, BlockHeader, and Block objects.
import DifficultyObj
import MinersObj
import BlockHeaderObj
import BlockObj

#Serialize libs.
import ../../../Network/Serialize/SerializeCommon

import ../../../Network/Serialize/Merit/SerializeBlock
import ../../../Network/Serialize/Merit/ParseBlockHeader
import ../../../Network/Serialize/Merit/ParseBlock

import ../../../Network/Serialize/Merit/SerializeDifficulty
import ../../../Network/Serialize/Merit/ParseDifficulty

#Finals lib.
import finals

#Blockchain object.
finalsd:
    type Blockchain* = object
        #DB Function Box.
        db*: DatabaseFunctionBox

        #Block time (part of the chain params).
        blockTime* {.final.}: Natural
        #Starting Difficulty (part of the chain params).
        startDifficulty* {.final.}: Difficulty

        #Height.
        height*: Natural
        #seq of every Blok Header.
        headers: seq[BlockHeader]
        #seq of all the Blocks in RAM.
        blocks: seq[Block]

        #Current Difficulty.
        difficulty*: Difficulty

#Create a Blockchain object.
proc newBlockchainObj*(
    db: DatabaseFunctionBox,
    genesis: string,
    blockTime: Natural,
    startDifficultyArg: Hash[384]
): Blockchain {.forceCheck: [].} =
    #Create the start difficulty.
    var startDifficulty: Difficulty
    try:
        startDifficulty = newDifficultyObj(
            0,
            1,
            startDifficultyArg
        )
    except ValueError:
        doAssert(false, "Couldn't create the Blockchain's starting difficulty.")

    #Create the Blockchain.
    result = Blockchain(
        db: db,

        blockTime: blockTime,
        startDifficulty: startDifficulty,

        difficulty: startDifficulty
    )
    #Finalize the Block Time and Start Difficulty.
    result.ffinalizeBlockTime()
    result.ffinalizeStartDifficulty()

    #Grab the tip from the DB.
    var tip: string = ""
    try:
        tip = db.get("merit_tip")
    #If the tip isn't defined, this is the first boot.
    except DBReadError:
        #Create a Genesis Block.
        var genesisBlock: Block
        try:
            genesisBlock = newBlockObj(
                0,
                genesis.pad(48).toArgonHash(),
                nil,
                @[],
                newMinersObj(@[]),
                0,
                0
            )
        except ValueError as e:
            doAssert(false, "Couldn't create the Genesis Block due to a ValueError: " & e.msg)
        except ArgonError as e:
            doAssert(false, "Couldn't create the Genesis Block due to an ArgonError: " & e.msg)
        #Grab the tip.
        tip = genesisBlock.header.hash.toString()

        #Save the tip, the Genesis Block, and the starting Difficulty.
        try:
            db.put("merit_tip", tip)
            db.put("merit_" & tip, genesisBlock.serialize())
            db.put("merit_difficulty", result.difficulty.serialize())
        except DBWriteError as e:
            doAssert(false, "Couldn't write the Genesis Block to the DB: " & e.msg)

    #Load every header.
    var
        headers: seq[BlockHeader]
        last: BlockHeader
        i: int = 0
    try:
        last = parseBlockHeader(db.get("merit_" & tip).substr(0, BLOCK_HEADER_LEN - 1))
    except ValueError as e:
        doAssert(false, "Couldn't parse a Block Header from the Database: " & e.msg)
    except BLSError as e:
        doAssert(false, "Couldn't parse a Block Header's Aggregate Signature from the Database: " & e.msg)
    except ArgonError as e:
        doAssert(false, "Couldn't hash a Block Header from the Database: " & e.msg)
    except DBReadError as e:
        doAssert(false, "Couldn't find/load a Block Header from the Database: " & e.msg)
    headers = newSeq[BlockHeader](last.nonce + 1)

    while last.nonce != 0:
        headers[i] = last
        try:
            last = parseBlockHeader(db.get("merit_" & last.last.toString()).substr(0, BLOCK_HEADER_LEN - 1))
        except ValueError as e:
            doAssert(false, "Couldn't parse a Block Header from the Database: " & e.msg)
        except BLSError as e:
            doAssert(false, "Couldn't parse a Block Header's Aggregate Signature from the Database: " & e.msg)
        except ArgonError as e:
            doAssert(false, "Couldn't hash a Block Header from the Database: " & e.msg)
        except DBReadError as e:
            doAssert(false, "Couldn't find/load a Block Header from the Database: " & e.msg)
        inc(i)
    headers[i] = last

    #Set the blockchain's height and create a seq for the headers.
    result.height = headers.len
    result.headers = newSeq[BlockHeader](result.height)
    #Load the headers.
    for header in headers:
        result.headers[header.nonce] = header

    #Load the blocks we want to cache.
    result.blocks = newSeq[Block](min(10, headers.len))
    try:
        if headers.len < 10:
            var loading: Block
            for h in countdown(headers.len - 1, 0):
                loading = parseBlock(db.get("merit_" & headers[h].hash.toString()))
                result.blocks[loading.header.nonce] = loading
        else:
            #We store the headers in reverse order.
            for h in 0 ..< 10:
                result.blocks[9 - h] = parseBlock(db.get("merit_" & headers[h].hash.toString()))
    except ValueError as e:
        doAssert(false, "Couldn't parse a Block we're supposed to cache from the Database: " & e.msg)
    except BLSError as e:
        doAssert(false, "Couldn't parse a Block we're supposed to cache's Aggregate Signature OR Miners from the Database: " & e.msg)
    except ArgonError as e:
        doAssert(false, "Couldn't hash a Block we're supposed to cache from the Database: " & e.msg)
    except DBReadError as e:
        doAssert(false, "Couldn't load a Block we're supposed to cache from the Database: " & e.msg)

    #Load the Difficulty.
    try:
        result.difficulty = parseDifficulty(db.get("merit_difficulty"))
    except ValueError as e:
        doAssert(false, "Loaded an invalid Difficulty from the Database: " & e.msg)
    except DBReadError as e:
        doAssert(false, "Couldn't load the Difficulty from the Database: " & e.msg)

#Adds a block.
proc add*(
    blockchain: var Blockchain,
    newBlock: Block
) {.forceCheck: [].} =
    inc(blockchain.height)
    blockchain.headers.add(newBlock.header)
    blockchain.blocks.add(newBlock)

    #Delete the block we're no longer caching.
    if blockchain.blocks.len > 10:
        blockchain.blocks.delete(0)

    #Save the block to the database.
    try:
        blockchain.db.put("merit_" & newBlock.header.hash.toString(), newBlock.serialize())
        blockchain.db.put("merit_tip", newBlock.header.hash.toString())
    except DBWriteError as e:
        doAssert(false, "Couldn't save a block to the Database: " & e.msg)

#Block getter.
proc `[]`*(
    blockchain: Blockchain,
    nonce: Natural
): Block {.forceCheck: [
    IndexError
].} =
    if nonce >= blockchain.height:
        raise newException(IndexError, "That nonce is greater than the Blockchain height.")

    if blockchain.height < 10:
        return blockchain.blocks[nonce]

    if nonce >= blockchain.height - 10:
        result = blockchain.blocks[nonce - (blockchain.height - 10)]
    else:
        try:
            result = parseBlock(blockchain.db.get("merit_" & blockchain.headers[nonce].hash.toString()))
        except ValueError as e:
            doAssert(false, "Couldn't parse a Block we were asked for from the Database: " & e.msg)
        except BLSError as e:
            doAssert(false, "Couldn't parse a Block we were asked for's Aggregate Signature OR Miners from the Database: " & e.msg)
        except ArgonError as e:
            doAssert(false, "Couldn't hash a Block we were asked for from the Database: " & e.msg)
        except DBReadError as e:
            doAssert(false, "Couldn't load a Block we were asked for from the Database: " & e.msg)


#Gets the last Block.
func tip*(
    blockchain: Blockchain
): Block {.inline, forceCheck: [].} =
    blockchain.blocks[^1]
