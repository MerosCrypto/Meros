#Epochs DB Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Transactions lib.
import ../../../../src/Database/Transactions/Transactions

#Consensus lib.
import ../../../../src/Database/Consensus/Consensus

#MeritHolderRecord object.
import ../../../../src/Database/common/objects/MeritHolderRecordObj

#Miners object.
import ../../../../src/Database/Merit/objects/MinersObj

#Difficulty, Block, Blockchain, and State libs.
import ../../../../src/Database/Merit/Difficulty
import ../../../../src/Database/Merit/Block
import ../../../../src/Database/Merit/Blockchain
import ../../../../src/Database/Merit/State

#Epochs lib.
import ../../../../src/Database/Merit/Epochs

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
        #Functions.
        functions: GlobalFunctionBox = newGlobalFunctionBox()
        #Database.
        db: DB = newTestDatabase()
        #Consensus.
        consensus: Consensus = newConsensus(
            functions,
            db,
            Hash[384](),
            Hash[384]()
        )
        #Blockchain.
        blockchain: Blockchain = newBlockchain(
            db,
            "EPOCHS_TEST_DB",
            30,
            "".pad(48).toHash(384)
        )
        #Transactions.
        transactions: Transactions = newTransactions(
            db,
            consensus,
            blockchain
        )
        #State.
        state: State = newState(db, 5, blockchain.height)
        #Epochs.
        epochs: Epochs = newEpochs(
            db,
            consensus,
            blockchain
        )

        #Hashes.
        hashes: seq[seq[Hash[384]]] = @[]
        #Hash we're randomizing.
        hash: Hash[384]
        #Table of a Merit Holder to every hash they signed.
        signed: Table[BLSPublicKey, seq[Hash[384]]] = initTable[BLSPublicKey, seq[Hash[384]]]()
        #Verification we're creating.
        verif: SignedVerification
        #Verifications used in a MeritRemoval.
        verif1: SignedVerification
        verif2: SignedVerification
        #MeritHolderRecords.
        records: seq[MeritHolderRecord] = @[]
        #List of pending removals.
        pending: seq[SignedMeritRemoval] = @[]
        #Table of Malicious MeritHolders.
        malicious: Table[BLSPublicKey, bool] = initTable[BLSPublicKey, bool]()

        #List of MeritHolders.
        holders: seq[MinerWallet] = @[]
        #List of new MeritHolders.
        newHolders: seq[MinerWallet] = @[]
        #List of MeritHolders used to grab a miner from.
        potentials: seq[MinerWallet] = @[]
        #Miners we're mining to.
        miners: seq[Miner] = @[]
        #Remaining amount of Merit.
        remaining: int
        #Amount to pay the miner.
        amount: int
        #Index of the miner we're choosing.
        miner: int

        #Block we're mining.
        mining: Block
        #Shifted Epoch.
        epoch: Epoch

    #Init the Function Box.
    functions.init(addr transactions)

    #Compare the Epochs against the reloaded Epochs.
    proc compare() =
        #Reload the Epochs.
        var reloaded: Epochs = newEpochs(
            db,
            consensus,
            blockchain
        )

        #Compare the Epochs.
        compare(epochs, reloaded)

    #Iterate over 20 'rounds'.
    for i in 1 .. 20:
        #Add a seq for the hashes.
        hashes.add(@[])
        #If Merit has been mined, create hashes.
        if i != 1:
            for _ in 0 ..< rand(20) + 2:
                for b in 0 ..< hash.data.len:
                    hash.data[b] = uint8(rand(255))

                hashes[^1].add(hash)

                #Register the Transaction.
                var tx: Transaction = Transaction()
                tx.hash = hash
                transactions.transactions[tx.hash] = tx
                consensus.register(transactions, state, tx, i)

            #For every viable holder, verify a random amount of hashes from each section.
            for holder in holders:
                if malicious.hasKey(holder.publicKey):
                    continue
                if rand(10) == 0:
                    malicious[holder.publicKey] = true

                if not malicious.hasKey(holder.publicKey):
                    for s in countdown(min(hashes.len - 1, 5), 1):
                        for _ in 0 ..< 3:
                            #Grab a Hash.
                            hash = hashes[^s][rand(max(hashes[^s].len - 1, 0))]

                            #Make sure we didn't already sign it.
                            if signed[holder.publicKey].contains(hash):
                                continue

                            #Create the Signed Verification.
                            verif = newSignedVerificationObj(hash)
                            holder.sign(verif, consensus[holder.publicKey].height)
                            signed[holder.publicKey].add(hash)

                            #Add it to the Consensus DAG.
                            consensus.add(state, verif)
                #Create a MeritRemoval.
                else:
                    verif1 = newSignedVerificationObj(hash)
                    holder.sign(verif1, consensus[holder.publicKey].height)
                    verif2 = newSignedVerificationObj(hash)
                    holder.sign(verif2, consensus[holder.publicKey].height)
                    pending.add(
                        newSignedMeritRemoval(
                            false,
                            verif1,
                            verif2,
                            @[
                                verif1.signature,
                                verif2.signature
                            ].aggregate()
                        )
                    )
                    consensus.flag(state, pending[^1])

        #Create the new records.
        records = @[]
        for holder in holders:
            if consensus.malicious.hasKey(holder.publicKey):
                records.add(newMeritHolderRecord(
                    holder.publicKey,
                    consensus[holder.publicKey].archived + 1,
                    consensus.malicious[holder.publicKey][0].merkle
                ))
                continue

            #Skip over MeritHolders with no Verifications.
            if consensus[holder.publicKey].height == 0:
                continue

            #Continue if this user doesn't have unarchived Verifications.
            if consensus[holder.publicKey].archived == consensus[holder.publicKey].height - 1:
                continue

            #Since there are unarchived Elements, add a MeritHolderRecord.
            records.add(newMeritHolderRecord(
                holder.publicKey,
                consensus[holder.publicKey].height - 1,
                consensus[holder.publicKey].merkle.hash
            ))

        #Create a random amount of Merit Holders.
        potentials = holders
        newHolders = @[]
        for _ in 0 ..< rand(5) + 2:
            holders.add(newMinerWallet())
            newHolders.add(holders[^1])
            signed[holders[^1].publicKey] = @[]

        #Randomize the miners
        miners = newSeq[Miner](rand(holders.len - newHolders.len) + newHolders.len)
        remaining = 100
        for m in 0 ..< miners.len:
            #Set the amount to pay the miner.
            amount = rand(remaining - 1) + 1
            #Make sure everyone gets at least 1 and we don't go over 100.
            if (remaining - amount) < (miners.len - m):
                amount = 1
            #But if this is the last account...
            if m == miners.len - 1:
                amount = remaining

            #Subtract the amount from remaining.
            remaining -= amount

            #Set the Miner.
            if m < newHolders.len:
                miners[m] = newMinerObj(
                    newHolders[m].publicKey,
                    amount
                )
            else:
                miner = rand(potentials.len - 1)
                miners[m] = newMinerObj(
                    potentials[miner].publicKey,
                    amount
                )
                potentials.del(miner)

        #Create the Block. We don't need to pass an aggregate signature because the blockchain doesn't test for that; MainMerit does.
        mining = newBlankBlock(
            nonce = i,
            last = blockchain.tip.header.hash,
            records = records,
            miners = newMinersObj(miners)
        )
        #Mine it.
        while not blockchain.difficulty.verify(mining.header.hash):
            inc(mining)

        #Add it to the Blockchain.
        blockchain.processBlock(mining)

        #Mark the MeritRemovals as archived.
        for mr in pending:
            consensus.archive(mr)

        #Add it to the State.
        state.processBlock(blockchain, mining)

        #Shift the records onto the Epochs.
        epoch = epochs.shift(consensus, @[], records)

        #Delete the Merit of every Malicious MeritHolder.
        for mr in pending:
            state.remove(mr.holder, mining)
        pending = @[]

        #Mark the records as archived.
        consensus.archive(state, epochs.latest, epoch)

        #Commit the DB.
        db.commit(mining.nonce)

        #Compare the Epochs.
        compare()

    echo "Finished the Database/Merit/Epochs DB Test."
