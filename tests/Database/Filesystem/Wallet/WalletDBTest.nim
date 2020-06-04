import os
import random
import sets, tables

import ../../../../src/lib/[Util, Hash]
import ../../../../src/Wallet/[MinerWallet, Wallet]

import ../../../../src/Database/Merit/objects/EpochsObj
import ../../../../src/Database/Transactions/objects/TransactionObj

import ../../../../src/Database/Filesystem/Wallet/WalletDB

import ../../../Fuzzed

suite "WalletDB":
  setup:
    var
      wallet: WalletDB

      inputs: seq[tuple[transaction: int, input: Input]] = @[]
      transactions: seq[tuple[finalized: bool, transaction: Transaction]] = @[]
      lookup: Table[Hash[256], Transaction] = initTable[Hash[256], Transaction]()

      finalizedNonces: int = 0
      unfinalizedNonces: int = 0
      finalizedTransactions: int = 0

      tx: Transaction

    #Delete any old database.
    removeFile("./data/NimTests/test-wallet" & $getThreadID())

    #Open the database.
    wallet = newWalletDB("./data/NimTests/test-wallet" & $getThreadID(), 1073741824)

    proc compare(
      w1: WalletDB,
      w2: WalletDB
    ) =
      check:
        w1.wallet.privateKey == w2.wallet.privateKey
        w1.miner.privateKey == w2.miner.privateKey
        w1.finalizedNonces == w2.finalizedNonces
        w1.unfinalizedNonces == w2.unfinalizedNonces
        w1.verified.len == w2.verified.len
        w1.elementNonce == w2.elementNonce

      for v in w1.verified.keys():
        check w1.verified[v] == w2.verified[v]

      #Close the reloaded DB.
      w2.close()

  midFuzzTest "Reloaded WalletDB/detects Verifying Competing.":
    #Fill it with 250 Transactions.
    for t in 0 ..< 250:
      tx = Transaction()
      tx.hash = newRandomHash()

      #Non-funded inputs.
      if rand(5) == 0:
        for i in 0 ..< rand(255):
          tx.inputs.add(newInput(newRandomHash()))
          inputs.add((transactions.len, tx.inputs[^1]))
      #Funded inputs.
      else:
        for i in 0 ..< rand(255):
          tx.inputs.add(newFundedInput(newRandomHash(), rand(255)))
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

        #Commit the Transactions.
        wallet.commit(
          epoch,
          proc (
            hash: Hash[256]
          ): Transaction {.gcsafe, raises: [
            IndexError
          ].} =
            try:
              {.gcsafe.}:
                result = lookup[hash]
            except KeyError as e:
              raise newException(IndexError, e.msg)
        )

        #Update the finalizedTransactions/finalizedNonces variables.
        while finalizedTransactions < transactions.len:
          if not transactions[finalizedTransactions].finalized:
            break
          finalizedNonces += transactions[finalizedTransactions].transaction.inputs.len
          inc(finalizedTransactions)
        check finalizedNonces == wallet.finalizedNonces

      #Create a Transaction which competes with randomly selected inputs.
      var
        fnCache: int = wallet.finalizedNonces
        amount: int = min(rand(254) + 1, ((unfinalizedNonces - finalizedNonces) * 3) div 4)
        input: tuple[transaction: int, input: Input]
      tx = Transaction()
      if inputs.len != finalizedNonces:
        #Select a continuous range of inputs.
        if rand(1) == 0:
          #Grab an unfinalized input.
          block grabContinuousInputs:
            var i: int = rand(high(inputs) - finalizedNonces) + finalizedNonces
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
            var used: HashSet[int] = initHashSet[int]()
            while true:
              #Grab an unfinalized input.
              var i: int = rand(high(inputs) - finalizedNonces) + finalizedNonces
              if used.contains(i):
                continue
              used.incl(i)
              input = inputs[i]

              #If the input wasn't finalized, use it.
              #This happens when there's a gap in finalization.
              if not transactions[input.transaction].finalized:
                break

            #Add the input.
            tx.inputs.add(input.input)

      #'Verify' it.
      expect ValueError:
        #Happens when there's no unfinalized nonces.
        if tx.inputs.len == 0:
          raise newException(ValueError, "")
        wallet.verifyTransaction(tx)

      #Clear it for safety.
      tx = Transaction()

      #Check the finalizedNonces field.
      check:
        fnCache == wallet.finalizedNonces
        wallet.finalizedNonces == finalizedNonces

      #Reload and compare the Wallet DBs.
      compare(wallet, newWalletDB("./data/NimTests/test-wallet" & $getThreadID(), 1073741824))

    #Close the DB.
    wallet.close()
