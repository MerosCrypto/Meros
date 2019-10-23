#Blockchain DB Test.

#Util lib.
import ../../../../src/lib/Util

#Hash and Merkle libs.
import ../../../../src/lib/Hash
import ../../../../src/lib/Merkle

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Element lib.
import ../../../../src/Database/Consensus/Elements/Element

#Difficulty, Block, Blockchain, and State libs.
import ../../../../src/Database/Merit/Difficulty
import ../../../../src/Database/Merit/Block
import ../../../../src/Database/Merit/Blockchain
import ../../../../src/Database/Merit/State

#Merit Testing lib.
import ../TestMerit

#Compare Merit lib.
import ../CompareMerit

#Tables lib.
import tables

#Random standard lib.
import random

#Create a valid VerificationPacket.
proc newValidVerificationPacket(
    blockchain: Blockchain,
    holders: seq[BLSPublicKey]
): VerificationPacket =
    var hash: Hash[384]
    for b in 0 ..< 48:
        hash.data[b] = uint8(rand(255))

    result = newVerificationPacketObj(hash)
    for holder in holders:
        if rand(1) == 0:
            result.holders.add(
                blockchain.miners[
                    holders[rand(high(holders))]
                ]
            )

    #Make sure there's at least one holder.
    if result.holders.len == 0:
        result.holders.add(
            blockchain.miners[
                holders[rand(high(holders))]
            ]
        )

    if result.holders.len == 0:
        doAssert(false)

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #Database.
        db: DB = newTestDatabase()
        #Starting Difficultty.
        startDifficulty: Hash[384] = "00AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA".toHash(384)
        #Blockchain.
        blockchain: Blockchain = newBlockchain(
            db,
            "BLOCKCHAIN_TEST",
            30,
            startDifficulty
        )
        #State. This is needed for the Blockchain's nickname table.
        state: State = newState(
            db,
            10,
            1
        )

        #Transaction hash.
        hash: Hash[384]
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

    #Compare the Blockchain against the reloaded Blockchain.
    proc compare() =
        #Reload the Blockchain.
        var reloaded: Blockchain = newBlockchain(
            db,
            "BLOCKCHAIN_TEST",
            30,
            startDifficulty
        )

        #Compare the Blockchains.
        compare(blockchain, reloaded)

    #Iterate over 20 'rounds'.
    for _ in 1 .. 20:
        if state.holders.len != 0:
            #Randomize the Packets.
            packets = @[]
            for _ in 0 ..< rand(300):
                packets.add(newValidVerificationPacket(blockchain, state.holders))

        #Randomize the Elements.

        #Decide if this is a nickname or new miner Block.
        if (miners.len == 0) or (rand(2) == 0):
            #New miner.
            miner = miners.len
            miners.add(newMinerWallet())

            #Create the Block with the new miner.
            mining = newBlankBlock(
                uint32(0),
                blockchain.tail.header.hash,
                miners[miner],
                rand(100000),
                char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                packets,
                elements
            )
        else:
            #Grab a random miner.
            miner = rand(high(miners))

            #Create the Block with the existing miner.
            mining = newBlankBlock(
                uint32(0),
                blockchain.tail.header.hash,
                uint16(miner),
                miners[miner],
                rand(100000),
                char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                packets,
                elements
            )

        #Mine it.
        while blockchain.difficulty.difficulty > mining.header.hash:
            miners[miner].hash(mining.header, mining.header.proof + 1)

        #Add it to the Blockchain and State.
        blockchain.processBlock(mining)
        state.processBlock(blockchain)

        #Commit the DB.
        db.commit(blockchain.height)

        #Compare the Blockchains.
        compare()

    echo "Finished the Database/Merit/Blockchain/DB Test."
