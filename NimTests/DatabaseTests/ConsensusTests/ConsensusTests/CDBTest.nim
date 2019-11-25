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
        #Functions.
        functions: GlobalFunctionBox = newGlobalFunctionBox()
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
        #Consensus.
        consensus: Consensus = newConsensus(
            functions,
            db,
            Hash[384](),
            Hash[384]()
        )
        #Transactions.
        transactions: Transactions = newTransactions(
            db,
            merit.blockchain
        )

        #Merit Holders.
        holders: seq[MinerWallet] = @[]
        #Packets to include in the next Block.
        packets: seq[VerificationPacket] = @[]
        #Aggregate signature to include in the next Block.
        aggregate: BLSSignature = nil

    #Init the Function Box.
    functions.init(addr transactions)

    #Mine and add a Block.
    proc mineBlock() =
        #Grab a holder and create a Block.
        var
            miner: MinerWallet
            mining: Block
        if (rand(1) == 0) or (holders.len == 0):
            miner = newMinerWallet()
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
        consensus.archive(merit.state, merit.epochs.latest, epoch)

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
            Hash[384](),
            Hash[384]()
        )

        #Compare the Consensus DAGs.
        compare(consensus, reloaded)

    #Iterate over 20 'rounds'.
    for r in 1 .. 20:
        #Clear the packets and aggregate.
        packets = @[]
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
            packets.add(newSignedVerificationPacketObj(hash))

            #Grab random holders to sign the packet.
            var sv: SignedVerification
            for h in 0 ..< holders.len:
                if rand(1) == 0:
                    continue

                packets[^1].holders.add(uint16(h))

                sv = newSignedVerificationObj(packets[^1].hash)
                holders[h].sign(sv)
                aggregate = if aggregate.isNil: sv.signature else: @[aggregate, sv.signature].aggregate()

                consensus.add(merit.state, sv)

            #Make sure at least one holder signed the packet.
            if packets[^1].holders.len == 0:
                packets[^1].holders.add(uint16(rand(high(holders))))

                sv = newSignedVerificationObj(packets[^1].hash)
                holders[int(packets[^1].holders[0])].sign(sv)
                aggregate = if aggregate.isNil: sv.signature else: @[aggregate, sv.signature].aggregate()

                consensus.add(merit.state, sv)

        #Compare the Consensus DAGs.
        compare()

    echo "Finished the Database/Consensus/Consensus/DB Test."
