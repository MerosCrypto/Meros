import random

import ../../../../src/Network/Serialize/Consensus/[
  SerializeVerificationPacket,
  ParseVerificationPacket
]

import ../../../Fuzzed
import ../../../Database/Consensus/Elements/TestElements
import ../../../Database/Consensus/CompareConsensus

suite "SerializeVerificationPacket":
  setup:
    var
      packet: SignedVerificationPacket = newRandomVerificationPacket()
      reloaded: VerificationPacket = packet.serialize().parseVerificationPacket()

  midFuzzTest "Compare the Elements/serializations.":
    compare(packet, reloaded)
    check packet.serialize() == reloaded.serialize()
