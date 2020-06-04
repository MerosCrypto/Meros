import random

import ../../../../src/Wallet/MinerWallet

import ../../../../src/Network/Serialize/Consensus/[
  SerializeDataDifficulty,
  ParseDataDifficulty
]

import ../../../Fuzzed
import ../../../Database/Consensus/Elements/TestElements
import ../../../Database/Consensus/CompareConsensus

suite "SerializeDataDifficulty":
  setup:
    var
      dataDiff: SignedDataDifficulty = newRandomDataDifficulty()
      reloadedDD: DataDifficulty = dataDiff.serialize().parseDataDifficulty()
      reloadedSDD: SignedDataDifficulty = dataDiff.signedSerialize().parseSignedDataDifficulty()

  lowFuzzTest "Compare the Elements/serializations.":
    compare(dataDiff, reloadedDD)
    compare(dataDiff, reloadedSDD)

    check:
      dataDiff.signature == reloadedSDD.signature
      dataDiff.serialize() == reloadedDD.serialize()
      dataDiff.signedSerialize() == reloadedSDD.signedSerialize()
