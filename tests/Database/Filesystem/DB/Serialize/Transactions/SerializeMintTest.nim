#Serialize Mint Test.

import deques

#Fuzzing lib.
import ../../../../../Fuzzed

#Util lib.
import ../../../../../../src/lib/Util

#Hash lib.
import ../../../../../../src/lib/Hash

#Epochs lib.
import ../../../../../../src/Database/Merit/Epochs

#Mint lib.
import ../../../../../../src/Database/Transactions/Mint

#Serialize libs.
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/SerializeMint
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/ParseMint

#Compare Transactions lib.
import ../../../../Transactions/CompareTransactions

#Random standard lib.
import random

suite "SerializeMint":
  midFuzzTest "Serialize and parse.":
    var
      #Mint.
      mint: Mint
      #Reloaded Mint.
      reloaded: Mint

      #Hash.
      hash: Hash[256]
      #Outputs.
      outputs: seq[MintOutput]

    #Randomize the hash.
    for b in 0 ..< hash.data.len:
      hash.data[b] = uint8(rand(255))

    #Randomize the outputs.
    outputs = newSeq[MintOutput](rand(99) + 1)
    for o in 0 ..< outputs.len:
      outputs[o] = newMintOutput(uint16(rand(65535)), uint64(rand(high(int32))))

    #Create the Mint.
    mint = newMint(hash, outputs)

    #Serialize it and parse it back.
    reloaded = hash.parseMint(mint.serialize())

    #Compare the Mints.
    compare(mint, reloaded)

    #Test the serialized versions.
    check(mint.serialize() == reloaded.serialize())
