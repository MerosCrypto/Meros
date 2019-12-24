#Transactions DB Test.

import unittest2

#Fuzzing lib.
import ../../Fuzzed

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#Wallet libs.
import ../../../src/Wallet/Wallet
import ../../../src/Wallet/MinerWallet

#VerificationPacket lib.
import ../../../src/Database/Consensus/Elements/VerificationPacket

#Merit lib.
import ../../../src/Database/Merit/Merit

#Transactions lib.
import ../../../src/Database/Transactions/Transactions

#Test Database lib.
import ../TestDatabase

#Test Merit lib.
import ../TestMerit

#Compare Transactions lib.
import CompareTransactions

#Sets standard lib.
import sets

#Tables standard lib.
import tables

#Random standard lib.
import random

suite "Transactions":
    setup:
        #Seed Random via the time.
        randomize(int64(getTime()))

        var
            #Database.
            db: DB = newTestDatabase()

            #Merit.
            merit: Merit = newMerit(
                db,
                "TRANSACTIONS_TEST",
                30,
                "".pad(48),
                100
            )
            #Transactions.
            transactions: Transactions = newTransactions(
                db,
                merit.blockchain
            )

            #MeritHolders.
            holders: seq[MinerWallet] = @[
                newMinerWallet(),
                newMinerWallet(),
                newMinerWallet(),
                newMinerWallet(),
                newMinerWallet(),
                newMinerWallet()
            ]
            #Wallets.
            wallets: seq[Wallet] = @[]
            #Mint Hash.
            #This hash is supposed to be the hash of the last Block.
            #Since we don't queue actions, yet handle them individually, we need unique hashes.
            #We just increment this blank hash to get a new hash. It's a nonce.
            mintHash: Hash[384]

            #Transactions.
            txs: seq[Transaction] = @[]
            #Table of a hash to the block it first appeared on.
            first: Table[Hash[384], int] = initTable[Hash[384], int]()

            #Packets.
            packets: seq[VerificationPacket]
            #New Block.
            newBlock: Block

        #Verify a transaction.
        proc verify(
            tx: Transaction,
            holder: int
        ) =
            packets.add(newVerificationPacketObj(tx.hash))
            packets[^1].holders.add(uint16(holder))

            if not first.hasKey(tx.hash):
                if (tx of Claim) or (tx of Send):
                    transactions.verify(tx.hash)

                first[tx.hash] = merit.blockchain.height
                txs.add(tx)

        #Give each holder Merit.
        for holder in holders:
            newBlock = newBlankBlock(
                last = merit.blockchain.tail.header.hash,
                miner = holder
            )
            merit.processBlock(newBlock)
            transactions.archive(merit.postProcessBlock()[0])

    midFuzzTest "Verify transactions.":
        #Clear packets.
        packets = @[]

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
                    spendable: seq[FundedInput] = @[]
                #Calculate the balance/spendable UTXOs.
                for input in transactions.getUTXOs(wallet.publicKey):
                    spendable.add(input)
                    balance += transactions[input.hash].outputs[input.nonce].amount

                #Fund them if they need funding.
                if balance <= amount:
                    #Increment mintHash.
                    if mintHash.data[^1] == 255:
                        mintHash.data[^1] = 0
                        inc(mintHash.data[^2])
                    inc(mintHash.data[^1])

                    #Create the Mint.
                    var
                        holder: int = rand(high(holders))
                        mintAmount: uint64 = amount - balance + uint64(rand(5000) + 1)
                    
                    transactions.mint(mintHash, @[newReward(uint16(holder), mintAmount)])

                    #Create the Claim.
                    var claim: Claim = newClaim(@[newFundedInput(mintHash, 0)], wallet.publicKey)
                    holders[holder].sign(claim)
                    transactions.add(
                        claim,
                        proc (
                                nick: uint16
                            ): BLSPublicKey =
                        holders[int(nick)].publicKey
                    )

                    verify(claim, 0)

                    #Update the UTXOs/balance.
                    spendable.add(newFundedInput(claim.hash, 0))
                    balance += transactions[mintHash].outputs[0].amount

                #Select a recepient.
                var recepient: EdPublicKey = wallets[rand(
                        wallets.high)].publicKey
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

                verify(send, 0)

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

                verify(data, 0)

        #Randomly select old transactions.
        var reused: HashSet[Hash[384]] = initHashSet[Hash[384]]()
        for _ in 0 ..< 10:
            var tx: Transaction = txs[rand(high(txs))]
            if (
                (first[tx.hash] < merit.blockchain.height - 5) or
                (first[tx.hash] == merit.blockchain.height) or
                (reused.contains(tx.hash))
            ):
                continue

            verify(tx, merit.blockchain.height - first[tx.hash])
            reused.incl(tx.hash)

        #Add a block.
        newBlock = newBlankBlock(
            last = merit.blockchain.tail.header.hash,
            miner = holders[^1],
            packets = packets
        )

        #Add it,
        merit.processBlock(newBlock)

        #Archive the epoch.
        transactions.archive(merit.postProcessBlock()[0])

        #Commit the DB.
        commit(merit.blockchain.height)

        #Compare the Transactions DAGs.
        var reloaded: Transactions = newTransactions(db, merit.blockchain)
        compare(transactions, reloaded)
