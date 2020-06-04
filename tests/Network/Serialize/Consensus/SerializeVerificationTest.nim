import random

import ../../../../src/Wallet/MinerWallet

import ../../../../src/Network/Serialize/Consensus/[
  SerializeVerification,
  ParseVerification
]

import ../../../Fuzzed
import ../../../Database/Consensus/Elements/TestElements
import ../../../Database/Consensus/CompareConsensus

suite "SerializeVerification":
  setup:
    var
      verif: SignedVerification = newRandomVerification()
      reloadedSV: SignedVerification = verif.signedSerialize().parseSignedVerification()

  lowFuzzTest "Compare the Elements/serializations.":
    compare(verif, reloadedSV)

    check:
      verif.signature == reloadedSV.signature
      verif.signedSerialize() == reloadedSV.signedSerialize()
