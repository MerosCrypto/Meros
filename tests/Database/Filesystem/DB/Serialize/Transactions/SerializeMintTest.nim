import random

import ../../../../../../src/lib/[Util, Hash]

import ../../../../../../src/Database/Merit/Epochs
import ../../../../../../src/Database/Transactions/Mint

import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/[
  SerializeMint,
  ParseMint
]

import ../../../../../Fuzzed
import ../../../../Transactions/CompareTransactions

suite "SerializeMint":
  midFuzzTest "Serialize and parse.":
    var
      mint: Mint
      reloaded: Mint
      hash: Hash[256] = newRandomHash()
      outputs: seq[MintOutput]

    outputs = newSeq[MintOutput](rand(99) + 1)
    for o in 0 ..< outputs.len:
      outputs[o] = newMintOutput(uint16(rand(65535)), uint64(rand(high(int32))))

    mint = newMint(hash, outputs)
    reloaded = hash.parseMint(mint.serialize())
    compare(mint, reloaded)
    check mint.serialize() == reloaded.serialize()
