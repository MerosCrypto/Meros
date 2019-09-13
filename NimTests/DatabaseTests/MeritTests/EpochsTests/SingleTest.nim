#Epochs Single Test. Verifies that 1 Verification = 1000.

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
        blockchain: Blockchain = newBlockchain(db, "EPOCH_SINGLE_TEST", 1, "".pad(48).toHash(384))
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
        miner: MinerWallet = newMinerWallet()
        #SignedVerification object.
        verif: SignedVerification
        #Rewards.
        rewards: seq[Reward]

    #Init the Function Box.
    functions.init(addr transactions)

    #Register the Transaction.
    var tx: Transaction = Transaction()
    tx.hash = hash
    transactions.transactions[tx.hash] = tx
    consensus.register(transactions, state, tx, 0)

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

    #Shift on the records.
    rewards = epochs.shift(
        consensus,
        @[],
        @[
            newMeritHolderRecord(
                miner.publicKey,
                0,
                hash
            )
        ]
    ).calculate(state)
    assert(rewards.len == 0)

    #Shift 4 over.
    for _ in 0 ..< 4:
        rewards = epochs.shift(consensus, @[], @[]).calculate(state)
        assert(rewards.len == 0)

    #Next shift should result in a Rewards of key 0, 1000.
    rewards = epochs.shift(consensus, @[], @[]).calculate(state)
    assert(rewards.len == 1)
    assert(rewards[0].key == miner.publicKey)
    assert(rewards[0].score == 1000)

    echo "Finished the Database/Merit/Epochs Single Test."
