import ../../../../../lib/[Errors, Util, Hash]
import ../../../../../Wallet/MinerWallet

import ../../../../Merit/Block

import ../../../../../Network/Serialize/SerializeCommon

import ../../../../../Network/Serialize/Consensus/[
  SerializeVerification,
  SerializeVerificationPacket,
  SerializeMeritRemoval
]

import ../../../../../Network/Serialize/Merit/SerializeBlockHeader

proc serialize*(
  blockArg: Block
): string {.forceCheck: [].} =
  result =
    blockArg.header.serialize() &
    blockArg.body.packetsContents.serialize() &
    blockArg.body.packets.len.toBinary(INT_LEN)

  for packet in blockArg.body.packets:
    result &= packet.serialize()

  result &= blockArg.body.elements.len.toBinary(INT_LEN)
  for elem in blockArg.body.elements:
    result &= elem.serializeContents()

  result &= blockArg.body.aggregate.serialize()
