import random

import ../../../../src/Wallet/MinerWallet

import ../../../../src/Network/Serialize/Consensus/[
  SerializeMeritRemoval,
  ParseMeritRemoval
]

import ../../../Fuzzed
import ../../../Database/Consensus/Elements/TestElements
import ../../../Database/Consensus/CompareConsensus

suite "SerializeMeritRemoval":
  setup:
    var
      mr: SignedMeritRemoval = newRandomMeritRemoval()
      reloadedSMR: SignedMeritRemoval = mr.serialize().parseSignedMeritRemoval()

  highFuzzTest "Compare the Elements/serializations.":
    compare(mr, reloadedSMR)

    check:
      mr.signature == reloadedSMR.signature
      mr.serialize() == reloadedSMR.serialize()
