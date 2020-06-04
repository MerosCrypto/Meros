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
      reloadedMR: MeritRemoval = mr.serialize().parseMeritRemoval()
      reloadedSMR: SignedMeritRemoval = mr.signedSerialize().parseSignedMeritRemoval()

  highFuzzTest "Compare the Elements/serializations.":
    compare(mr, reloadedMR)
    compare(mr, reloadedSMR)

    check:
      mr.signature == reloadedSMR.signature
      mr.serialize() == reloadedMR.serialize()
      mr.signedSerialize() == reloadedSMR.signedSerialize()
