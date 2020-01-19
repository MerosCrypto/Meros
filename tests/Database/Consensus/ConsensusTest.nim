#Consensus Test.

#Test lib.
import unittest

#Fuzzing lib.
import ../../Fuzzed

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Merit lib.
import ../../../src/Database/Merit/Merit

#Consensus lib.
import ../../../src/Database/Consensus/Consensus

#Transactions lib.
import ../../../src/Database/Transactions/Transactions

#Test Database lib.
import ../TestDatabase

#Test Merit lib.
import ../Merit/TestMerit

#Compare Consensus lib.
import CompareConsensus

#Random standard lib.
import random

#Tables lib.
import tables

suite "Consensus":
    setup:
        #Seed random.
        randomize(int64(getTime()))

    midFuzzTest "Reloaded malicious table.":
        var
            #Database.
            db: DB = newTestDatabase()

            #Merit.
            merit: Merit = newMerit(
                db,
                "CONSENSUS_DB_TEST",
                1,
                $Hash[256](),
                25
            )

            #Functions.
            functions: GlobalFunctionBox = newTestGlobalFunctionBox(addr merit.blockchain, nil)

            #Consensus.
            consensus: Consensus = newConsensus(
                functions,
                db,
                merit.state,
                Hash[256](),
                Hash[256]()
            )

            #Currently have Merit Removals.
            malicious: seq[uint16] = @[]

        #Create 100 Merit Holders.
        for h in 0 ..< 100:
            consensus.archive(merit.state, @[], @[], newEpoch(), uint16(h), -1)

        #Iterate over 100 actions.
        for a in 0 ..< 100:
            #Create three removals.
            for r in 0 ..< 3:
                var
                    diff1: Hash[256]
                    diff2: Hash[256]
                for b in 0 ..< 32:
                    diff1.data[b] = uint8(rand(255))
                    diff2.data[b] = uint8(rand(255))

                var
                    sendDiff: SendDifficulty = newSendDifficultyObj(rand(200000), diff1)
                    dataDiff: DataDifficulty = newDataDifficultyObj(rand(200000), diff2)
                    removal: SignedMeritRemoval = newSignedMeritRemovalObj(
                        uint16(rand(500)),
                        rand(1) == 0,
                        sendDiff,
                        dataDiff,
                        newMinerWallet().sign("")
                    )
                sendDiff.holder = removal.holder
                dataDiff.holder = removal.holder

                consensus.flag(merit.blockchain, merit.state, removal)
                if not malicious.contains(removal.holder):
                    malicious.add(removal.holder)

            #Remove an existing holder's MeritRemovals.
            var toRemove: int = rand(malicious.len - 1)
            consensus.remove(malicious[toRemove], 0)
            malicious.del(toRemove)

            #Reload Consensus.
            var reloaded: Consensus = newConsensus(
                functions,
                db,
                merit.state,
                Hash[256](),
                Hash[256]()
            )

            #Compare the Consensus DAGs.
            compare(consensus, reloaded)

    test "Reloaded Consensus.":
        var
            #Database.
            db: DB = newTestDatabase()

            #Merit.
            merit: Merit = newMerit(
                db,
                "CONSENSUS_DB_TEST",
                1,
                $Hash[256](),
                625
            )
            #Transactions.
            transactions: Transactions = newTransactions(
                db,
                merit.blockchain
            )

            #Functions.
            functions: GlobalFunctionBox = newTestGlobalFunctionBox(addr merit.blockchain, addr transactions)

            #Consensus.
            consensus: Consensus = newConsensus(
                functions,
                db,
                merit.state,
                Hash[256](),
                Hash[256]()
            )

            #Merit Holders.
            holders: seq[MinerWallet] = @[]
            #Packets to include in the next Block.
            packets: seq[VerificationPacket] = @[]
            #Elements to include in the next Block.
            elements: seq[BlockElement] = @[]
            #List of Transactions we didn't add every SignedVerification for.
            unsigned: seq[Hash[256]] = @[]
            #SignedVerification used to generate signatures.
            sv: SignedVerification
            #Aggregate signature to include in the next Block.
            aggregate: BLSSignature = newBLSSignature()

        #Mine and add a Block.
        proc mineBlock() =
            #Grab a holder and create a Block.
            var
                miner: MinerWallet
                mining: Block
            if (rand(74) == 0) or (holders.len == 0):
                miner = newMinerWallet()
                miner.nick = uint16(holders.len)
                holders.add(miner)

                mining = newBlankBlock(
                    last = merit.blockchain.tail.header.hash,
                    sketchSalt = char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                    miner = miner,
                    packets = packets,
                    elements = elements,
                    aggregate = aggregate
                )
            else:
                var h: int = rand(high(holders))
                miner = holders[h]

                mining = newBlankBlock(
                    last = merit.blockchain.tail.header.hash,
                    sketchSalt = char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                    nick = uint16(h),
                    miner = miner,
                    packets = packets,
                    elements = elements,
                    aggregate = aggregate
                )

            #Check who has their Merit removed.
            var removed: set[uint16] = {}
            for elem in mining.body.elements:
                if elem of MeritRemoval:
                    consensus.flag(merit.blockchain, merit.state, cast[MeritRemoval](elem))
                    removed.incl(elem.holder)

            #Add a Block to the Blockchain to generate a holder.
            merit.processBlock(mining)

            #Copy the State.
            var rewardsState: State = merit.state

            #Add the Block to the Epochs and State.
            var
                epoch: Epoch
                incd: uint16
                decd: int
            (epoch, incd, decd) = merit.postProcessBlock()

            #Archive the Epochs.
            consensus.archive(merit.state, mining.body.packets, mining.body.elements, epoch, incd, decd)

            #Have the Consensus handle every person who suffered a MeritRemoval.
            for removee in removed:
                consensus.remove(removee, rewardsState[removee])

            #Add the elements.
            for elem in elements:
                case elem:
                    of SendDifficulty as sendDiff:
                        consensus.add(merit.state, sendDiff)
                    of DataDifficulty as dataDiff:
                        consensus.add(merit.state, dataDiff)
            elements = @[]

            #Archive the hashes handled by the popped Epoch.
            transactions.archive(epoch)

            #Commit the DBs.
            db.commit(merit.blockchain.height)

        #Mine a Block so there's a holder.
        mineBlock()

        #Compare the Consensus against the reloaded Consensus.
        proc compare() =
            #Reload the Consensus.
            var reloaded: Consensus = newConsensus(
                functions,
                db,
                merit.state,
                Hash[256](),
                Hash[256]()
            )

            #Compare the Consensus DAGs.
            compare(consensus, reloaded)

        #Iterate over 1250 'rounds'.
        for r in 1 .. 1250:
            #Clear the packets, unsigned table, and aggregate.
            packets = @[]
            unsigned = @[]
            aggregate = newBLSSignature()

            #Create a random amount of 'Transaction's.
            for _ in 0 ..< rand(2) + 1:
                #Randomize the hash.
                var hash: Hash[256]
                for b in 0 ..< hash.data.len:
                    hash.data[b] = uint8(rand(255))

                #Register the Transaction.
                var tx: Transaction = Transaction()
                tx.hash = hash
                transactions.transactions[tx.hash] = tx
                consensus.register(merit.state, tx, r)

                #Create a packet for the Transaction.
                packets.add(newVerificationPacketObj(hash))

                #Grab random holders to sign the packet.
                for h in 0 ..< holders.len:
                    if rand(1) == 0:
                        continue

                    packets[^1].holders.add(uint16(h))

                    sv = newSignedVerificationObj(packets[^1].hash)
                    holders[h].sign(sv)
                    aggregate = if aggregate.isInf: sv.signature else: @[aggregate, sv.signature].aggregate()

                    #Decide to add it to Consensus as a live SignedVerification or later as a VerificationPacket.
                    if rand(3) == 0:
                        if not unsigned.contains(tx.hash):
                            unsigned.add(tx.hash)
                    else:
                        consensus.add(merit.state, sv)

                #Make sure at least one holder signed the packet.
                if packets[^1].holders.len == 0:
                    packets[^1].holders.add(uint16(rand(high(holders))))

                    sv = newSignedVerificationObj(packets[^1].hash)
                    holders[int(packets[^1].holders[0])].sign(sv)
                    aggregate = if aggregate.isInf: sv.signature else: @[aggregate, sv.signature].aggregate()

                    if rand(3) == 0:
                        if not unsigned.contains(tx.hash):
                            unsigned.add(tx.hash)
                    else:
                        consensus.add(merit.state, sv)

            #Iterate through the existing Epochs to add new Verifications to old Transactions.
            for epoch in merit.epochs:
                if rand(1) == 0:
                    continue

                for tx in epoch.keys():
                    if rand(1) == 0:
                        continue

                    #Create the packet.
                    packets.add(newVerificationPacketObj(tx))

                    #Run against each Merit Holder.
                    for h in 0 ..< holders.len:
                        if epoch[tx].contains(uint16(h)) or (rand(2) == 0):
                            continue

                        #Add the holder.
                        packets[^1].holders.add(uint16(h))

                        #Create the SignedVerification.
                        sv = newSignedVerificationObj(packets[^1].hash)
                        holders[h].sign(sv)
                        aggregate = @[aggregate, sv.signature].aggregate()

                        if rand(3) == 0:
                            if not unsigned.contains(tx):
                                unsigned.add(tx)
                        else:
                            consensus.add(merit.state, sv)

                    #If no holder was added, delete the packet.
                    if packets[^1].holders == @[]:
                        packets.del(high(packets))

            #Slow but functional.
            for tx in unsigned:
                for packet in packets:
                    if tx == packet.hash:
                        consensus.add(merit.state, packet)
                        break

            #Add Difficulties.
            var
                holder: int = rand(holders.len - 1)
                diff1: Hash[256]
                diff2: Hash[256]
                sendDiff: SignedSendDifficulty
                dataDiff: SignedDataDifficulty
            for b in 0 ..< 32:
                diff1.data[b] = uint8(rand(255))
                diff2.data[b] = uint8(rand(255))

            sendDiff = newSignedSendDifficultyObj(consensus.getArchivedNonce(uint16(holder)) + 1, diff1)
            sendDiff.holder = uint16(holder)
            elements.add(sendDiff)

            holder = rand(holders.len - 1)
            dataDiff = newSignedDataDifficultyObj(consensus.getArchivedNonce(uint16(holder)) + 1, diff2)
            dataDiff.holder = uint16(holder)
            elements.add(dataDiff)

            if rand(125) == 0:
                #Add a Merit Removal.
                holder = rand(holders.len - 1)
                while merit.state[uint16(holder)] == 0:
                    holder = rand(holders.len - 1)
                for b in 0 ..< 32:
                    diff1.data[b] = uint8(rand(255))
                    diff2.data[b] = uint8(rand(255))

                var
                    e1: SendDifficulty
                    e2: DataDifficulty
                e1 = newSendDifficultyObj(0, diff1)
                e1.holder = uint16(holder)
                e2 = newDataDifficultyObj(0, diff2)
                e2.holder = uint16(holder)

                elements.add(newMeritRemoval(
                    uint16(holder),
                    false,
                    e1,
                    e2,
                    merit.state.holders
                ))

            #Mine the packets.
            mineBlock()

            #Compare the Consensus DAGs.
            compare()
