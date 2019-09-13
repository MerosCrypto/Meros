#Epochs Perfect 1000 Test. Verifies that 3 Verifications still result in a total of 1000.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../../src/Database/common/objects/MeritHolderRecordObj

#Transactions lib.
import ../../../../src/Database/Transactions/Transactions

#Consensus lib.
import ../../../../src/Database/Consensus/Consensus

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Merit Testing functions.
import ../TestMerit

#Tables standard lib.
import tables

proc test*() =
    var
        #Functions.
        functions: GlobalFunctionBox = newGlobalFunctionBox()
        #Database Function Box.
        db: DB = newTestDatabase()
        #Consensus.
        consensus: Consensus = newConsensus(
            functions,
            db,
            Hash[384](),
            Hash[384]()
        )
        #Blockchain.
        blockchain: Blockchain = newBlockchain(db, "EPOCH_PERFECT_1000_TEST", 1, "".pad(48).toHash(384))
        #State.
        state: State = newState(db, 100, blockchain.height)
        #Epochs.
        epochs: Epochs = newEpochs(db, consensus, blockchain)
        #Transactions.
        transactions: Transactions = newTransactions(
            db,
            consensus,
            blockchain
        )

        #Hash.
        hash: Hash[384] = "".pad(48, char(128)).toHash(384)
        #MinerWallets.
        miners: seq[MinerWallet] = @[
            newMinerWallet(),
            newMinerWallet(),
            newMinerWallet()
        ]
        #SignedVerification object.
        verif: SignedVerification
        #MeritHolderRecords.
        records: seq[MeritHolderRecord] = @[]
        #Rewards.
        rewards: seq[Reward]

    #Init the Function Box.
    functions.init(addr transactions)

    #Register the Transaction.
    var tx: Transaction = Transaction()
    tx.hash = hash
    transactions.transactions[tx.hash] = tx
    consensus.register(transactions, state, tx, 0)

    for miner in miners:
        #Give the miner Merit.
        state.processBlock(
            blockchain,
            newBlankBlock(
                miners = newMinersObj(@[
                    newMinerObj(
                        miner.publicKey,
                        100
                    )
                ])
            )
        )

        #Create the Verification.
        verif = newSignedVerificationObj(hash)
        miner.sign(verif, 0)

        #Add the Verification.
        consensus.add(state, verif)

        #Add a MeritHolderRecord.
        records.add(newMeritHolderRecord(
            miner.publicKey,
            0,
            hash
        ))

    #Shift on the records.
    rewards = epochs.shift(consensus, @[], records).calculate(state)
    assert(rewards.len == 0)

    #Shift 4 over.
    for _ in 0 ..< 4:
        rewards = epochs.shift(consensus, @[], @[]).calculate(state)
        assert(rewards.len == 0)

    #Next shift should result in a Rewards of key 0: 334, key 1: 333, and key 2: 333.
    rewards = epochs.shift(consensus, @[], @[]).calculate(state)

    #Veirfy the length.
    assert(rewards.len == 3)

    #Verify each key is unique and one of our keys.
    for r1 in 0 ..< rewards.len:
        for r2 in 0 ..< rewards.len:
            if r1 == r2:
                continue
            assert(rewards[r1].key != rewards[r2].key)

        for m in 0 ..< miners.len:
            if rewards[r1].key == miners[m].publicKey:
                break

            if m == miners.len - 1:
                assert(false)

    #Verify the scores.
    assert(rewards[0].score == 334)
    assert(rewards[1].score == 333)
    assert(rewards[2].score == 333)

    echo "Finished the Database/Merit/Epochs Perfect 1000 Test."
