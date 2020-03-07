#Blockchain Test.

#Test lib.
import unittest

#Errors lib.
import ../../../src/lib/Errors

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Element libs.
import ../../../src/Database/Consensus/Elements/Elements

#Difficulty, Block, Blockchain, and State libs.
import ../../../src/Database/Merit/Difficulty
import ../../../src/Database/Merit/Block
import ../../../src/Database/Merit/Blockchain
import ../../../src/Database/Merit/State

#Merit Testing lib.
import TestMerit

#Compare Merit lib.
import CompareMerit

#Random standard lib.
import random

#Sets standard lib.
import sets

#Tables standard lib.
import tables

#Starting Difficultty.
const START_DIFFICULTY: Hash[256] = "00AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA".toHash(256)

suite "Blockchain":
    setup:
        #Seed random.
        randomize(int64(getTime()))

    test "Reloaded and reverted Blockchain.":
        var
            #Database.
            db: DB = newTestDatabase()
            #Full copy of the Blocks independent of any database.
            blocks: seq[Block] = @[]
            #Blockchains.
            blockchains: seq[Blockchain] = @[newBlockchain(
                db,
                "BLOCKCHAIN_DB_TEST",
                30,
                START_DIFFICULTY
            )]
            #State. This is needed for the Blockchain's nickname table.
            state: State = newState(
                db,
                10,
                blockchains[0]
            )
            #Database copies.
            databases: seq[Table[string, string]] = @[]

            #Used Element nonces.
            elementNonces: Table[int, int] = initTable[int, int]()

            #Transaction hash.
            hash: Hash[256]
            #Packets.
            packets: seq[VerificationPacket]
            #Elements.
            elements: seq[BlockElement]
            #Miners.
            miners: seq[MinerWallet]
            #Selected miner for the next Block.
            miner: int
            #Block.
            mining: Block

        proc backupDatabase() =
            databases.add(initTable[string, string]())
            for key in db.merit.used:
                databases[^1][key] = db.lmdb.get("merit", key)

        #Iterate over 20 'rounds'.
        for i in 1 .. 20:
            if state.holders.len != 0:
                #Randomize the Packets.
                packets = @[]
                for _ in 0 ..< rand(300):
                    packets.add(newValidVerificationPacket(state.holders))

                #Randomize the Elements.
                elements = @[]
                if rand(1) == 0:
                    var
                        holder: int = rand(high(miners))
                        elementNonce: int
                    try:
                        elementNonce = elementNonces[holder]
                    except KeyError:
                        elementNonce = 0
                    elementNonces[holder] = elementNonce + 1

                    proc randomHash(): Hash[256] =
                        for b in 0 ..< 32:
                            result.data[b] = uint8(rand(255))

                    case rand(2):
                        of 0:
                            var sd: SignedSendDifficulty = newSignedSendDifficultyObj(elementNonce, uint32(rand(high(int32))))
                            miners[holder].sign(sd)
                            elements.add(sd)
                        of 1:
                            var dd: SignedDataDifficulty = newSignedDataDifficultyObj(elementNonce, uint32(rand(high(int32))))
                            miners[holder].sign(dd)
                            elements.add(dd)
                        of 2:
                            var
                                e1: SignedDataDifficulty
                                e2: SignedDataDifficulty
                            e1 = newSignedDataDifficultyObj(elementNonce, uint32(rand(high(int32))))
                            e2 = newSignedDataDifficultyObj(elementNonce, uint32(rand(high(int32))))
                            miners[holder].sign(e1)
                            miners[holder].sign(e2)

                            elements.add(newSignedMeritRemoval(
                                uint16(holder),
                                false,
                                e1,
                                e2,
                                @[e1.signature, e2.signature].aggregate(),
                                @[]
                            ))
                        else:
                            panic("Generated a number outside of the provided range.")

            #Decide if this is a nickname or new miner Block.
            if (miners.len == 0) or (rand(2) == 0):
                #New miner.
                miner = miners.len
                miners.add(newMinerWallet())
                miners[^1].nick = uint16(miner)

                #Create the Block with the new miner.
                mining = newBlankBlock(
                    uint32(0),
                    blockchains[^1].tail.header.hash,
                    uint16(rand(50000)),
                    char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                    miners[miner],
                    packets,
                    elements
                )
            else:
                #Grab a random miner.
                miner = rand(high(miners))

                #Create the Block with the existing miner.
                mining = newBlankBlock(
                    uint32(0),
                    blockchains[^1].tail.header.hash,
                    uint16(rand(50000)),
                    char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                    uint16(miner),
                    miners[miner],
                    packets,
                    elements
                )

            #Mine it.
            while blockchains[^1].difficulty.difficulty > mining.header.hash:
                miners[miner].hash(mining.header, mining.header.proof + 1)

            #Add it to the Blockchain and State.
            blockchains.add(blockchains[^1])
            blocks.add(mining)
            blockchains[^1].processBlock(mining)
            discard state.processBlock(blockchains[^1])

            #Commit the DB.
            db.commit(blockchains[^1].height)

            #Backup the Database.
            backupDatabase()

            #Compare the Blockchains.
            compare(blockchains[^1], newBlockchain(
                db,
                "BLOCKCHAIN_DB_TEST",
                30,
                START_DIFFICULTY
            ))

        #Revert every chain and compare the Databases are identical at each step.
        for c in countdown(blockchains.len - 2, 1):
            #Revert the Blockchain to the specified height.
            blockchains[^1].revert(state, blockchains[c].height)
            db.commit(blockchains[^1].height)

            #Compare the Blockchains.
            compare(blockchains[^1], blockchains[c])

            #Verify every key in the Database is the same.
            #We use the key list in the last Database to verify key deletion.
            for key in db.merit.used:
                if databases[c - 1].hasKey(key):
                    check(db.lmdb.get("merit", key) == databases[c - 1][key])
                else:
                    try:
                        discard db.lmdb.get("merit", key)
                        check(false)
                    except DBReadError:
                        discard

        #Add all the Blocks back to the last chain.
        for b in 1 ..< blocks.len:
            blockchains[^1].processBlock(blocks[b])
            discard state.processBlock(blockchains[^1])
            db.commit(blockchains[^1].height)

            #Verify every key in the Database is what it's supposed to be.
            for key in db.merit.used:
                if databases[b].hasKey(key):
                    check(db.lmdb.get("merit", key) == databases[b][key])
                else:
                    try:
                        discard db.lmdb.get("merit", key)
                        check(false)
                    except DBReadError:
                        discard

        #Test one last reversion of the full chain.
        blockchains[^1].revert(state, blockchains[1].height)
        db.commit(blockchains[^1].height)

        #Compare the Blockchains.
        compare(blockchains[^1], blockchains[1])

        #Verify every key in the Database is the same.
        for key in db.merit.used:
            if databases[0].hasKey(key):
                check(db.lmdb.get("merit", key) == databases[0][key])
            else:
                try:
                    discard db.lmdb.get("merit", key)
                    check(false)
                except DBReadError:
                    discard
