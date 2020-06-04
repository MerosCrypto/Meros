import random

import ../../../../src/Wallet/MinerWallet

import ../../../../src/Network/Serialize/Consensus/[
  SerializeSendDifficulty,
  ParseSendDifficulty
]

import ../../../Fuzzed
import ../../../Database/Consensus/Elements/TestElements
import ../../../Database/Consensus/CompareConsensus

suite "SerializeSendDifficulty":
  setup:
    var
      sendDiff: SignedSendDifficulty = newRandomSendDifficulty()
      reloadedSD: SendDifficulty = sendDiff.serialize().parseSendDifficulty()
      reloadedSSD: SignedSendDifficulty = sendDiff.signedSerialize().parseSignedSendDifficulty()

  lowFuzzTest "Compare the Elements/serializations.":
    compare(sendDiff, reloadedSD)
    compare(sendDiff, reloadedSSD)

    check:
      sendDiff.signature == reloadedSSD.signature
      sendDiff.serialize() == reloadedSD.serialize()
      sendDiff.signedSerialize() == reloadedSSD.signedSerialize()
