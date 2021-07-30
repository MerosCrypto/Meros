import random
import deques
import sets, tables

import ../../../Fuzzed

import ../../../../src/lib/[Errors, Hash]
import ../../../../src/objects/GlobalFunctionBoxObj

import ../../../../src/Database/Transactions/objects/TransactionObj
import ../../../../src/Database/Merit/objects/EpochsObj

suite "Family Management":
  setup:
    var
      genesis: Hash[256] = Hash[256]()
      transactions: Table[Hash[256], Transaction] = initTable[Hash[256], Transaction]()
      spenders: Table[Input, seq[Hash[256]]] = initTable[Input, seq[Hash[256]]]()
      functions: GlobalFunctionBox = newGlobalFunctionBox()

    #Create a genesis distinct from the magic hash (0) used for initial inputs.
    genesis.data[0] = 1

    functions.transactions.getTransaction = proc (
      hash: Hash[256]
    ): Transaction {.gcsafe.} =
      {.gcsafe.}:
        try:
          result = transactions[hash]
        except KeyError:
          panic("Epochs asked for a non-existent Transaction.")

    functions.transactions.getSpenders = proc (
      input: Input
    ): seq[Hash[256]] {.gcsafe.} =
      {.gcsafe.}:
        try:
          result = spenders[input]
        except KeyError:
          panic("Epochs asked for the spenders of a non-existent Input.")

    var epochs: Epochs = newEpochsObj(genesis, functions, 1)

    template register(
      hash: Hash[256],
      inputs: seq[Input],
      height: uint
    ) =
      for input in inputs:
        if not spenders.hasKey(input):
          spenders[input] = @[]
        spenders[input].add(hash)
      epochs.register(hash, inputs, height)

    proc randomHash(): Hash[256] =
      for b in 0 ..< 32:
        result.data[b] = uint8(rand(255))
    let hashesInEpochs: seq[Hash[256]] = @[
      randomHash(),
      randomHash(),
      randomHash()
    ]

  noFuzzTest "Pops off a single Transaction after 5 Blocks.":
    var tx: Hash[256] = randomHash()
    transactions[tx] = Transaction()

    #'Block' which adds the Transaction.
    register(hashesInEpochs[0], @[newInput(tx)], 2)
    check epochs.families.len == 1
    check epochs.currentTXs.len == 1
    check epochs.pop().len == 0

    #4 'Blocks' to get through Epochs.
    for _ in 0 ..< 4:
      check epochs.pop().len == 0

    #Get out of Epochs.
    check epochs.pop() == @[hashesInEpochs[0]].toHashSet()

    #Check the state as well.
    check epochs.height == 7
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5
    check epochs.currentTXs.len == 0
    check epochs.datas.len == 0

  noFuzzTest "Merges competitors.":
    var txs: seq[Hash[256]] = @[]
    for _ in 0 ..< 3:
      txs.add(randomHash())
      transactions[txs[^1]] = Transaction()

    register(hashesInEpochs[0], @[newInput(txs[0]), newInput(txs[1])], 2)
    check epochs.families.len == 1
    check epochs.currentTXs.len == 1

    register(hashesInEpochs[1], @[newInput(txs[0]), newInput(txs[2])], 2)
    check epochs.families.len == 1
    check epochs.currentTXs.len == 2
    check epochs.pop().len == 0

    for _ in 0 ..< 4:
      check epochs.pop().len == 0

    check epochs.pop() == hashesInEpochs[0 .. 1].toHashSet()

    check epochs.height == 7
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5
    check epochs.currentTXs.len == 0
    check epochs.datas.len == 0

  noFuzzTest "Merges multiple existing families.":
    var txs: seq[Hash[256]] = @[]
    for _ in 0 ..< 2:
      txs.add(randomHash())
      transactions[txs[^1]] = Transaction()

    register(hashesInEpochs[0], @[newInput(txs[0])], 2)
    check epochs.families.len == 1
    check epochs.currentTXs.len == 1
    register(hashesInEpochs[1], @[newInput(txs[1])], 2)
    check epochs.families.len == 2
    check epochs.currentTXs.len == 2
    register(hashesInEpochs[2], @[newInput(txs[0]), newInput(txs[1])], 2)
    check epochs.families.len == 1
    check epochs.currentTXs.len == 3
    check epochs.pop().len == 0

    for _ in 0 ..< 4:
      check epochs.pop().len == 0

    check epochs.pop() == hashesInEpochs.toHashSet()

    check epochs.height == 7
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5
    check epochs.currentTXs.len == 0
    check epochs.datas.len == 0

  noFuzzTest "Brings up competitors.":
    var txs: seq[Hash[256]] = @[]
    for _ in 0 ..< 3:
      txs.add(randomHash())
      transactions[txs[^1]] = Transaction()

    #Stagnates registration by a Block.
    register(hashesInEpochs[0], @[newInput(txs[0]), newInput(txs[1])], 2)
    check epochs.families.len == 1
    check epochs.currentTXs.len == 1
    check epochs.pop().len == 0
    register(hashesInEpochs[1], @[newInput(txs[0]), newInput(txs[2])], 3)
    check epochs.families.len == 1
    check epochs.currentTXs.len == 2
    check epochs.pop().len == 0

    for _ in 0 ..< 4:
      check epochs.pop().len == 0

    check epochs.pop() == hashesInEpochs[0 .. 1].toHashSet()

    check epochs.height == 8
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5
    check epochs.currentTXs.len == 0
    check epochs.datas.len == 0

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
    register(hashesInEpochs[0], @[newInput(txs[0]), newInput(txs[1])], 2)
    check epochs.families.len == 1
    check epochs.currentTXs.len == 1
    check epochs.pop().len == 0
    #Descendant.
    register(hashesInEpochs[1], @[newInput(txs[3])], 3)
    check epochs.families.len == 2
    check epochs.currentTXs.len == 2
    check epochs.pop().len == 0
    #Competitor.
    register(hashesInEpochs[2], @[newInput(txs[0]), newInput(txs[2])], 4)
    check epochs.families.len == 2
    check epochs.currentTXs.len == 3
    check epochs.pop().len == 0

    for _ in 0 ..< 4:
      check epochs.pop().len == 0

    check epochs.pop() == hashesInEpochs.toHashSet()

    check epochs.height == 9
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5
    check epochs.currentTXs.len == 0
    check epochs.datas.len == 0

  #This is really a test for our hash function and Nim's usage of it.
  #There's no reason to expect this to fail, yet it's extremely valid to test.
  noFuzzTest "Understands FundedInputs with different nonces yet the same hash aren't competitors.":
    var tx: Hash[256] = randomHash()
    transactions[tx] = Transaction()

    register(hashesInEpochs[0], cast[seq[Input]](@[newFundedInput(tx, 0)]), 2)
    check epochs.families.len == 1
    check epochs.currentTXs.len == 1
    check epochs.pop().len == 0
    register(hashesInEpochs[1], cast[seq[Input]](@[newFundedInput(tx, 1)]), 3)
    check epochs.families.len == 2
    check epochs.currentTXs.len == 2
    check epochs.pop().len == 0

    for _ in 0 ..< 3:
      check epochs.pop().len == 0

    check epochs.pop() == @[hashesInEpochs[0]].toHashSet()
    check epochs.currentTXs.len == 1
    check epochs.pop() == @[hashesInEpochs[1]].toHashSet()

    check epochs.height == 8
    check epochs.inputMap.len == 0
    check epochs.families.len == 0
    check epochs.epochs.len == 5
    check epochs.currentTXs.len == 0
    check epochs.datas.len == 0
