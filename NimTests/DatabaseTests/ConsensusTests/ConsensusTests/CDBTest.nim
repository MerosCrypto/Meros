#Consensus DB Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Consensus lib.
import ../../../../src/Database/Consensus/Consensus

#Transactions lib.
import ../../../../src/Database/Transactions/Transactions

#Test Database lib.
import ../../TestDatabase

#Test Merit lib.
import ../../MeritTests/TestMerit

#Compare Consensus lib.
import ../CompareConsensus

#Random standard lib.
import random

#Tables lib.
import tables

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #Database.
        db: DB = newTestDatabase()

        #Merit.
        merit: Merit = newMerit(
            db,
            "CONSENSUS_TEST",
            10,
            $Hash[384](),
            10
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
            Hash[384](),
            Hash[384]()
        )

        #Merit Holders.
        holders: seq[MinerWallet] = @[]
        #Packets to include in the next Block.
        packets: seq[VerificationPacket] = @[]
        #List of Transactions we didn't add every SignedVerification for.
        unsigned: seq[Hash[384]] = @[]
        #SignedVerification used to generate signatures.
        sv: SignedVerification
        #Aggregate signature to include in the next Block.
        aggregate: BLSSignature = nil

    #Mine and add a Block.
    proc mineBlock() =
        #Grab a holder and create a Block.
        var
            miner: MinerWallet
            mining: Block
        if (rand(1) == 0) or (holders.len == 0):
            miner = newMinerWallet()
            miner.nick = uint16(holders.len)
            holders.add(miner)

            mining = newBlankBlock(
                last = merit.blockchain.tail.header.hash,
                sketchSalt = char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                miner = miner,
                packets = packets,
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
                aggregate = aggregate
            )

        #Mine it.
        while merit.blockchain.difficulty.difficulty > mining.header.hash:
            miner.hash(mining.header, mining.header.proof + 1)

        #Add a Block to the Blockchain to generate a holder.
        merit.processBlock(mining)

        #Add the Block to the Epochs and State.
        var epoch: Epoch = merit.postProcessBlock()

        #Archive the Epochs.
        consensus.archive(merit.state, mining.body.packets, epoch)

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
            Hash[384](),
            Hash[384]()
        )

        #Compare the Consensus DAGs.
        compare(consensus, reloaded)

    #Iterate over 20 'rounds'.
    for r in 1 .. 20:
        #Clear the packets, unsigned table, and aggregate.
        packets = @[]
        unsigned = @[]
        aggregate = nil

        #Create a random amount of 'Transaction's.
        for _ in 0 ..< rand(2) + 1:
            #Randomize the hash.
            var hash: Hash[384]
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
                aggregate = if aggregate.isNil: sv.signature else: @[aggregate, sv.signature].aggregate()

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
                aggregate = if aggregate.isNil: sv.signature else: @[aggregate, sv.signature].aggregate()

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

        #Mine the packets.
        mineBlock()

        #Compare the Consensus DAGs.
        compare()

    echo "Finished the Database/Consensus/Consensus/DB Test."
test()
