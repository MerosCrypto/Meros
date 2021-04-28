import random

import ../../../../src/lib/Util
import ../../../../src/Wallet/Wallet

import ../../../../src/Database/Transactions/[Transaction, Data]

import ../../../../src/Network/Serialize/Transactions/[
  SerializeData,
  ParseData
]

import ../../../Fuzzed
import ../../../Database/Transactions/CompareTransactions

suite "SerializeData":
  setup:
    var
      dataStr: string
      data: Data
      reloaded: Data
      wallet: HDWallet = newWallet("").hd

  midFuzzTest "Serialize and parse.":
    #Create the data string.
    dataStr = newString(rand(255) + 1)
    for b in 0 ..< dataStr.len:
      dataStr[b] = char(rand(255))

    #Create the Data.
    data = newData(newRandomHash(), dataStr)
    wallet.sign(data)
    data.mine(uint32(5))

    reloaded = data.serialize().parseData(uint32(0))
    compare(data, reloaded)
    check data.serialize() == reloaded.serialize()
