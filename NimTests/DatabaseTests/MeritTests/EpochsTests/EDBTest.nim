#Epochs DB Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Verification lib.
import ../../../../src/Database/Consensus/Elements/VerificationPacket

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Merit Testing functions.
import ../TestMerit

#Compare Merit lib.
import ../CompareMerit

#Tables standard lib.
import tables

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #Database.
        db: DB = newTestDatabase()
        #Blockchain.
        blockchain: Blockchain = newBlockchain(
            db,
            "EPOCHS_TEST_DB",
            30,
            "".pad(48).toHash(384)
        )
        #State.
        state: State = newState(db, 5, blockchain.height)
        #Epochs.
        epochs: Epochs = newEpochs(blockchain)

        #Table of a hash to the block it first appeared on.
        first: Table[Hash[384], int] = initTable[Hash[384], int]()
        #Table of a hash to every nick which has already signed it.
        signed: Table[Hash[384], seq[uint16]] = initTable[Hash[384], seq[uint16]]()

        #List of MeritHolders.
        holders: seq[MinerWallet] = @[]
        #Miner we've selected.
        miner: uint16

        #Packets we've created.
        packets: seq[VerificationPacket]
        #Block we're creating.
        newBlock: Block

    #Iterate over 20 'rounds'.
    for i in 1 .. 20:
        #If Merit has been mined, create packets.
        if i != 1:
            packets = @[]
            for _ in 0 ..< rand(20) + 2:
                packets.add(newValidVerificationPacket(state.holders))
                first[packets[^1].hash] = i
                signed[packets[^1].hash] = packets[^1].holders

            #Also create some packets using older hashes.
            for b in 1 ..< min(i, 5):
                for packet in blockchain[i - b].body.packets:
                    if rand(2) == 0:
                        if first[packet.hash] + 6 > i:
                            continue

                        if signed[packet.hash].len == holders.len:
                            continue

                        packets.add(newValidVerificationPacket(state.holders, signed[packet.hash], packet.hash))

        #Create the block using either a new miner or an existing one.
        if (i == 1) or (rand(1) == 0):
            holders.add(newMinerWallet())
            newBlock = newBlankBlock(
                last = blockchain.tail.header.hash,
                miner = holders[^1],
                packets = packets
            )
        else:
            miner = uint16(rand(high(holders)))
            newBlock = newBlankBlock(
                last = blockchain.tail.header.hash,
                nick = miner,
                miner = holders[miner],
                packets = packets
            )

        #Add it to the Blockchain.
        blockchain.processBlock(newBlock)

        #Add it to the State.
        state.processBlock(blockchain)

        #Shift the records onto the Epochs.
        discard epochs.shift(blockchain.tail)

        #Commit the DB.
        db.commit(blockchain.height)

        #Compare the Epochs.
        compare(epochs, newEpochs(blockchain))

    echo "Finished the Database/Merit/Epochs DB Test."
