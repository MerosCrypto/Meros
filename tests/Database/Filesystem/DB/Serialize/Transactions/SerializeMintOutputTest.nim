import random

import ../../../../../../src/lib/Util

import ../../../../../../src/Database/Transactions/objects/TransactionObj

import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/[
  SerializeMintOutput,
  ParseMintOutput
]

import ../../../../../Fuzzed
import ../../../../Transactions/CompareTransactions

suite "SerializeMintOutput":
  lowFuzzTest "Serialize and parse.":
    var
      output: MintOutput = newMintOutput(
        uint16(rand(high(int16))),
        uint64(rand(high(int32)))
      )
      reloaded: MintOutput = output.serialize().parseMintOutput()
    compare(output, reloaded)
    check output.serialize() == reloaded.serialize()
