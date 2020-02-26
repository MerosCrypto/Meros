#Test lib.
import unittest

#Fuzzed lib.
import ../../../Fuzzed

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Wallet libs.
import ../../../../src/Wallet/Wallet
import ../../../../src/Wallet/MinerWallet

#Epoch object.
import ../../../../src/Database/Merit/objects/EpochsObj

#Input/Output objects.
import ../../../../src/Database/Transactions/objects/TransactionObj

#WalletDB lib.
import ../../../../src/Database/Filesystem/Wallet/WalletDB

#OS standard lib.
import os

#Random standard lib.
import random

#Tables standard lib.
import tables

suite "WalletDB":
    setup:
        var
            #Wallet DB.
            wallet: WalletDB

            #Seq of created inputs.
            inputs: seq[tuple[transaction: int, input: Input]] = @[]
            #Seq of created Transactions.
            transactions: seq[tuple[finalized: bool, transaction: Transaction]] = @[]
            #Lookup table.
            lookup: Table[Hash[256], Transaction] = initTable[Hash[256], Transaction]()

            #Track finalized/unfinalized indexes.
            finalizedNonces: int = 0
            unfinalizedNonces: int = 0
            finalizedTransactions: int = 0

            #Transaction.
            tx: Transaction
            #Hash.
            hash: Hash[256]

        #Delete any old database.
        removeFile("./data/NimTests/test-wallet" & $getThreadID())

        #Open the database.
        wallet = newWalletDB("./data/NimTests/test-wallet" & $getThreadID(), 1073741824)

        proc compare(
            w1: WalletDB,
            w2: WalletDB
        ) =
            check(w1.wallet.privateKey == w2.wallet.privateKey)
            check(w1.miner.privateKey == w2.miner.privateKey)

            check(w1.finalizedNonces == w2.finalizedNonces)
            check(w1.unfinalizedNonces == w2.unfinalizedNonces)
            check(w1.verified.len == w2.verified.len)
            for v in w1.verified.keys():
                check(w1.verified[v] == w2.verified[v])

            check(w1.elementNonce == w2.elementNonce)

            #Close the reloaded DB.
            w2.close()

    midFuzzTest "Reloaded WalletDB/detects Verifying Competing.":
        #Fill it with 250 Transactions.
        for t in 0 ..< 250:
            tx = Transaction()
            for b in 0 ..< 32:
                tx.hash.data[b] = uint8(rand(255))

            #Non-funded inputs.
            if rand(5) == 0:
                for i in 0 ..< rand(255):
                    for b in 0 ..< 32:
                        hash.data[b] = uint8(rand(255))
                    tx.inputs.add(newInput(hash))
                    inputs.add((transactions.len, tx.inputs[^1]))
            #Funded inputs.
            else:
                for i in 0 ..< rand(255):
                    for b in 0 ..< 32:
                        hash.data[b] = uint8(rand(255))
                    tx.inputs.add(newFundedInput(hash, rand(255)))
                    inputs.add((transactions.len, tx.inputs[^1]))

            #Register the Transaction.
            transactions.add((false, tx))
            lookup[tx.hash] = tx
            unfinalizedNonces += tx.inputs.len

            #'Verify' the new Transaction.
            wallet.verifyTransaction(tx)

            if rand(50) == 0:
                #Grab Transactions to finalize.
                var epoch: Epoch = newEpoch()
                for n in finalizedTransactions ..< transactions.len:
                    if transactions[n].finalized:
                        continue

                    if rand(40) != 0:
                        epoch[transactions[n].transaction.hash] = @[]
                        transactions[n].finalized = true

                #Update the finalizedTransactions/finalizedNonces variables.
                for n in finalizedTransactions ..< transactions.len:
                    if not transactions[n].finalized:
                        break
                    inc(finalizedTransactions)
                    finalizedNonces += transactions[n].transaction.inputs.len

                #Commit the Transactions.
                wallet.commit(
                    epoch,
                    proc (
                        hash: Hash[256]
                    ): Transaction {.raises: [
                        IndexError
                    ].} =
                        try:
                            result = lookup[hash]
                        except KeyError as e:
                            raise newException(IndexError, e.msg)
                )

            #Create a Transaction which competes with randomly selected inputs.
            var
                amount: int = min(rand(254) + 1, unfinalizedNonces - finalizedNonces)
                input: tuple[transaction: int, input: Input]
            tx = Transaction()
            #Select a continuous range of inputs.
            if rand(1) == 0:
                #Grab an unfinalized input.
                var i: int = max(rand(unfinalizedNonces - finalizedNonces - amount) + finalizedNonces - 1, 0)
                block grabContinuousInputs:
                    for _ in 0 ..< amount:
                        while true:
                            #If we hit the end, break.
                            if i == inputs.len:
                                break grabContinuousInputs

                            #Grab the next input.
                            input = inputs[i]
                            inc(i)

                            #If the input wasn't finalized, use it.
                            if not transactions[input.transaction].finalized:
                                break

                        #Add the input.
                        tx.inputs.add(input.input)
            #Select inputs randomly.
            else:
                for _ in 0 ..< amount:
                    while true:
                        #Grab an unfinalized input.
                        input = inputs[rand(high(inputs) - finalizedNonces) + finalizedNonces]

                        #If the input wasn't finalized, use it.
                        if not transactions[input.transaction].finalized:
                            break

                    #Add the input.
                    tx.inputs.add(input.input)

            #'Verify' it.
            try:
                #Happens when there's no unfinalized nonces.
                if tx.inputs.len == 0:
                    raise newException(ValueError, "")

                wallet.verifyTransaction(tx)

                #This should have raised.
                check(false)
            except ValueError:
                discard

            #Check the finalizedNonces field.
            check(wallet.finalizedNonces == finalizedNonces)

            #Reload and compare the Wallet DBs.
            compare(wallet, newWalletDB("./data/NimTests/test-wallet" & $getThreadID(), 1073741824))

        #Close the DB.
        wallet.close()
