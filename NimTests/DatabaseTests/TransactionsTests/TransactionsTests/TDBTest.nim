#Transactions DB Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Wallet libs.
import ../../../../src/Wallet/Wallet
import ../../../../src/Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../../src/Database/common/objects/MeritHolderRecordObj

#Consensus lib.
import ../../../../src/Database/Consensus/Consensus

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Transactions lib.
import ../../../../src/Database/Transactions/Transactions

#Test Database lib.
import ../../TestDatabase

#Compare Transactions lib.
import ../CompareTransactions

#Tables lib.
import tables

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #Database.
        db: DB = newTestDatabase()

        #Consensus.
        consensus: Consensus = newConsensus(db)
        #Merit.
        merit: Merit = newMerit(
            db,
            consensus,
            "BLOCKCHAIN_TEST",
            30,
            "".pad(48),
            100
        )
        #Transactions.
        transactions: Transactions = newTransactions(
            db,
            consensus,
            merit
        )

        #MeritHolder.
        holder: MinerWallet = newMinerWallet()
        #Wallets.
        wallets: seq[Wallet] = @[]

    #Compare the Transactions against the reloaded Transactions.
    proc compare() =
        #Reload the Transactions.
        var reloaded: Transactions = newTransactions(
            db,
            consensus,
            merit
        )

        #Compare the Transactionss.
        compare(transactions, reloaded)

    #Adds a Block, containing the passed records.
    proc addBlock() =
        #Create the new Block.
        var newBlock: Block = newBlockObj(
            merit.blockchain.height,
            merit.blockchain.tip.header.hash,
            nil,
            @[
                newMeritHolderRecord(
                    holder.publicKey,
                    consensus[holder.publicKey].height - 1,
                    "".pad(48).toHash(384)
                )
            ],
            newMinersObj(@[
                newMinerObj(holder.publicKey, 100)
            ]),
            getTime(),
            0
        )

        #Mine it.
        while not merit.blockchain.difficulty.verify(newBlock.header.hash):
            inc(newBlock)

        #Add it,
        merit.processBlock(newBlock)
        var epoch: Epoch = merit.postProcessBlock(consensus, @[], newBlock)

        #Manually clear the difficulty.
        merit.blockchain.difficulty = newDifficultyObj(
            merit.blockchain.difficulty.start,
            merit.blockchain.difficulty.endBlock,
            "".pad(48).toHash(384)
        )

        #Archive the Records.
        consensus.archive(newBlock.records)
        transactions.archive(consensus, epoch)

    #Add Verifications for an Transaction.
    proc verify(
        hash: Hash[384]
    ) =
        var verif: SignedVerification = newSignedVerificationObj(hash)
        holder.sign(verif, consensus[holder.publicKey].height)
        consensus.add(verif)
        transactions.markVerified(verif.hash)

    #Iterate over 20 'rounds'.
    for _ in 0 ..< 20:
        #Create a random amount of Wallets.
        for _ in 0 ..< rand(2) + 2:
            wallets.add(newWallet(""))

        #Create Transactions and verify them.
        for e in 0 ..< rand(9) + 1:
            #Grab a random Wallet.
            var
                sender: int = rand(wallets.len - 1)
                wallet: Wallet = wallets[sender]

            #Create a Send.
            if rand(1) == 0:
                var
                    #Decide how much to Send.
                    amount: uint64 = uint64(rand(10000) + 1)
                    #Current balance.
                    balance: uint64 = 0
                    #Spenable UTXOs.
                    spendable: seq[SendInput] = @[]
                #Calculate the balance/spendable UTXOs.
                for input in transactions.getUTXOs(wallet.publicKey):
                    spendable.add(input)
                    balance += transactions[input.hash].outputs[input.nonce].amount

                #Fund them if they need funding.
                if balance <= amount:
                    #Create the Mint.
                    var
                        mintee: MinerWallet = newMinerWallet()
                        mintAmount: uint64 = amount - balance + uint64(rand(5000) + 1)
                        mintHash: Hash[384] = transactions.mint(mintee.publicKey, mintAmount)

                    #Create the Claim.
                    var claim: Claim = newClaim(
                        mintHash,
                        wallet.publicKey
                    )
                    mintee.sign(claim)
                    transactions.add(claim)
                    verify(claim.hash)

                    #Update the UTXOs/balance.
                    spendable.add(newSendInput(claim.hash, 0))
                    balance += transactions[mintHash].outputs[0].amount

                #Select a recepient.
                var recepient: EdPublicKey = wallets[rand(wallets.high)].publicKey
                while recepient == wallet.publicKey:
                    recepient = wallets[rand(wallets.high)].publicKey

                #Create the Send.
                var send: Send = newSend(
                    spendable,
                    @[
                        newSendOutput(
                            recepient,
                            amount
                        ),
                        newSendOutput(
                            wallet.publicKey,
                            balance - amount
                        )
                    ]
                )
                wallet.sign(send)
                send.mine(Hash[384]())
                transactions.add(send)
                verify(send.hash)

                #Make sure spendable was properly set.
                doAssert(transactions.getUTXOs(wallet.publicKey).len == 1)
                doAssert(transactions.getUTXOs(wallet.publicKey)[0].hash == send.hash)
                doAssert(transactions.getUTXOs(wallet.publicKey)[0].nonce == 1)

            #Create a Data.
            else:
                var
                    dataStr: string = newString(rand(254) + 1)
                    data: Data
                for c in 0 ..< dataStr.len:
                    dataStr[c] = char(rand(255))

                data = newData(transactions.loadDataTip(wallet.publicKey), dataStr)
                wallet.sign(data)
                data.mine(Hash[384]())
                transactions.add(data)
                verify(data.hash)

        #Mine a Block.
        addBlock()

        #Commit the DB.
        commit(merit.blockchain.tip.nonce)

        #Compare the Transactions DAGs.
        compare()

    echo "Finished the Database/Transactions/Transactions/DB Test."

test()
