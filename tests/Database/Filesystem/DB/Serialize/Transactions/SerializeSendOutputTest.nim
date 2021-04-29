import random

import ../../../../../../src/lib/Util
import ../../../../../../src/Wallet/Wallet

import ../../../../../../src/Database/Transactions/objects/TransactionObj

import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/[
  SerializeSendOutput,
  ParseSendOutput
]

import ../../../../../Fuzzed
import ../../../../Transactions/CompareTransactions

suite "SerializeSendOutput":
  lowFuzzTest "Serialize and parse.":
    var
      output: SendOutput = newSendOutput(
        newWallet("").hd.publicKey,
        uint64(rand(int32.high))
      )
      reloaded: SendOutput = output.serialize().parseSendOutput()
    compare(output, reloaded)
    check output.serialize() == reloaded.serialize()
