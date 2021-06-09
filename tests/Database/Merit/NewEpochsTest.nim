import random
import sequtils
import deques
import sets, tables

import ../../Fuzzed

import ../../../src/lib/[Errors, Hash]
import ../../../src/objects/GlobalFunctionBoxObj

import ../../../src/Database/Transactions/objects/TransactionObj
import ../../../src/Database/Merit/objects/EpochsObj

suite "Epochs":
  setup:
    var
      genesis: Hash[256] = Hash[256]()
      transactions: Table[Hash[256], Transaction] = initTable[Hash[256], Transaction]()
      functions: GlobalFunctionBox = newGlobalFunctionBox()
    genesis.data[0] = 1
    functions.transactions.getTransaction = proc (
      hash: Hash[256]
    ): Transaction {.gcsafe.} =
      {.gcsafe.}:
        try:
          result = transactions[hash]
        except KeyError:
          panic("Epochs asked for non-existent Transaction.")

    var epochs: Epochs = newEpochsObj(genesis, functions, 1)

    proc randomHash(): Hash[256] =
      for b in 0 ..< 32:
        result.data[b] = uint8(rand(255))

  noFuzzTest "Pops off a single Transaction after 5 Blocks.":
    var tx: Hash[256] = randomHash()
    transactions[tx] = Transaction()

    #'Block' which adds the Transaction.
    epochs.register(@[newInput(tx)], 2)
    check epochs.families.len == 1
    discard epochs.pop()

    #4 'Blocks' to get through Epochs.
    for _ in 0 ..< 4:
      discard epochs.pop()

    #Get out of Epochs.
    check toSeq(epochs.pop().items()) == @[newInput(tx)]

    #Check the state as well.
    check epochs.height == 7
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5

  noFuzzTest "Merges competitors.":
    var txs: seq[Hash[256]] = @[]
    for _ in 0 ..< 3:
      txs.add(randomHash())
      transactions[txs[^1]] = Transaction()

    epochs.register(@[newInput(txs[0]), newInput(txs[1])], 2)
    check epochs.families.len == 1
    epochs.register(@[newInput(txs[0]), newInput(txs[2])], 2)
    check epochs.families.len == 1
    discard epochs.pop()

    for _ in 0 ..< 4:
      discard epochs.pop()

    check epochs.pop() == txs.mapIt(newInput(it)).toHashSet()

    check epochs.height == 7
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5

  noFuzzTest "Merges multiple existing families.":
    var txs: seq[Hash[256]] = @[]
    for _ in 0 ..< 2:
      txs.add(randomHash())
      transactions[txs[^1]] = Transaction()

    epochs.register(@[newInput(txs[0])], 2)
    check epochs.families.len == 1
    epochs.register(@[newInput(txs[1])], 2)
    check epochs.families.len == 2
    epochs.register(@[newInput(txs[0]), newInput(txs[1])], 2)
    check epochs.families.len == 1
    discard epochs.pop()

    for _ in 0 ..< 4:
      discard epochs.pop()

    check epochs.pop() == txs.mapIt(newInput(it)).toHashSet()

    check epochs.height == 7
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5

  noFuzzTest "Brings up competitors.":
    var txs: seq[Hash[256]] = @[]
    for _ in 0 ..< 3:
      txs.add(randomHash())
      transactions[txs[^1]] = Transaction()

    #Stagnates registration by a Block.
    epochs.register(@[newInput(txs[0]), newInput(txs[1])], 2)
    check epochs.families.len == 1
    discard epochs.pop()
    epochs.register(@[newInput(txs[0]), newInput(txs[2])], 3)
    check epochs.families.len == 1
    discard epochs.pop()

    for _ in 0 ..< 4:
      discard epochs.pop()

    check epochs.pop() == txs.mapIt(newInput(it)).toHashSet()

    check epochs.height == 8
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5

  noFuzzTest "Brings up descendants.":
    var txs: seq[Hash[256]] = @[]
    for i in 0 ..< 4:
      txs.add(randomHash())
      if i != 3:
        transactions[txs[^1]] = Transaction()
      else:
        transactions[txs[^1]] = Transaction(
          inputs: @[newInput(txs[1])]
        )

    #Base transaction.
    epochs.register(@[newInput(txs[0]), newInput(txs[1])], 2)
    check epochs.families.len == 1
    discard epochs.pop()
    #Descendant.
    epochs.register(@[newInput(txs[3])], 3)
    check epochs.families.len == 2
    discard epochs.pop()
    #Competitor.
    epochs.register(@[newInput(txs[0]), newInput(txs[2])], 4)
    check epochs.families.len == 2
    discard epochs.pop()

    for _ in 0 ..< 4:
      discard epochs.pop()

    check epochs.pop() == txs.mapIt(newInput(it)).toHashSet()

    check epochs.height == 9
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5

  #This is really a test for our hash function and Nim's usage of it.
  #There's no reason to expect this to fail, yet it's extremely valid to test.
  noFuzzTest "Understands FundedInputs with different nonces yet the same hash aren't competitors.":
    var tx: Hash[256] = randomHash()
    transactions[tx] = Transaction()

    epochs.register(cast[seq[Input]](@[newFundedInput(tx, 0)]), 2)
    check epochs.families.len == 1
    discard epochs.pop()
    epochs.register(cast[seq[Input]](@[newFundedInput(tx, 1)]), 3)
    check epochs.families.len == 2
    discard epochs.pop()

    for _ in 0 ..< 3:
      discard epochs.pop()

    check epochs.pop() == cast[seq[Input]](@[newFundedInput(tx, 0)]).toHashSet()
    check epochs.pop() == cast[seq[Input]](@[newFundedInput(tx, 1)]).toHashSet()

    check epochs.height == 8
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5
