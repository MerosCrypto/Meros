#Consensus DB Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../../src/Database/common/objects/MeritHolderRecordObj

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Transactions lib.
import ../../../../src/Database/Transactions/Transactions

#Consensus lib.
import ../../../../src/Database/Consensus/Consensus

#Test Database lib.
import ../../TestDatabase

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
        #State.
        state: State = newState(db, 1, 0)
        #Consensus.
        consensus: Consensus = newConsensus(db, Hash[384](), Hash[384]())
        #Transactions.
        transactions: Transactions = newTransactions(
            db,
            consensus,
            newBlockchain(db, "", 0, Hash[384]())
        )

        #MeritHolders.
        holders: seq[MinerWallet]
        #SignedVerification we just created.
        verif: SignedVerification
        #Transaction used to register the hash.
        tx: Transaction
        #Tips we're archiving.
        archiving: seq[MeritHolderRecord]

    #Compare the Consensus against the reloaded Consensus.
    proc compare() =
        #Reload the Consensus.
        var reloaded: Consensus = newConsensus(db, Hash[384](), Hash[384]())

        #Compare the Consensus DAGs.
        compare(consensus, reloaded)

    #Iterate over 20 'rounds'.
    for _ in 0 ..< 20:
        #Create a random amount of MeritHolders.
        for _ in 0 ..< rand(2) + 1:
            holders.add(newMinerWallet())

        #Create Elements.
        for e in 0 ..< rand(10):
            var
                #Grab a random MeritHolder.
                i: int = rand(holders.len - 1)
                holder: MinerWallet = holders[i]
                #Hash used in a SignedVerification.
                hash: Hash[384]
            #Randomize the hash.
            for b in 0 ..< hash.data.len:
                hash.data[b] = uint8(rand(255))
            #Create the Verification.
            verif = newSignedVerificationObj(hash)
            #Sign it.
            holder.sign(verif, consensus[holder.publicKey].height)

            #Register the Transaction.
            tx = Transaction()
            tx.hash = hash
            consensus.register(transactions, state, tx, 0)

            #Add it as a SignedVerification.
            if rand(1) == 0:
                consensus.add(state, verif, true)
            #Add it as a Verification.
            else:
                consensus.add(state, cast[Verification](verif), true)

        #Clear archiving and recalculate it.
        archiving = @[]
        for h in 0 ..< holders.len:
            if consensus[holders[h].publicKey].height - 1 == consensus[holders[h].publicKey].archived:
                continue

            archiving.add(
                newMeritHolderRecord(
                    holders[h].publicKey,
                    consensus[holders[h].publicKey].height - 1,
                    consensus[holders[h].publicKey].merkle.hash
                )
            )
        #Archive the records.
        consensus.archive(archiving, initTable[string, seq[BLSPublicKey]]())

        #Commit the DB.
        db.commit(0)

        #Compare the Consensus DAGs.
        compare()

    echo "Finished the Database/Consensus/Consensus/DB Test."
