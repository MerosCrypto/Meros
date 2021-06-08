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

    var epochs: Epochs = newEpochs(genesis, functions, 1)

    proc randomHash(): Hash[256] =
      for b in 0 ..< 32:
        result.data[b] = uint8(rand(255))

  noFuzzTest "Pops off a single Transaction after 5 Blocks.":
    var tx: Hash[256] = randomHash()
    transactions[tx] = Transaction()

    #'Block' which adds the Transaction.
    epochs.register(@[newInput(tx)], 2)
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

  #Test competitors are merged.
  #Test competitors are brought up.
  #Test descendants of competitors are brought up.
  #Test that two FundedInputs to the same Transaction yet different outputs are distinguished.
