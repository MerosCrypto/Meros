import ../../../../../lib/[Errors, Util, Hash]
import ../../../../../Wallet/MinerWallet

import ../../../../Merit/Block

import ../../../../../Network/Serialize/SerializeCommon

import ../../../../../Network/Serialize/Consensus/[
  SerializeElement,
  SerializeVerificationPacket
]

import ../../../../../Network/Serialize/Merit/SerializeBlockHeader
export SerializeBlockHeader

proc serialize*(
  blockArg: Block
): string {.forceCheck: [].} =
  result =
    blockArg.header.serialize(0) &
    blockArg.body.packetsContents.serialize() &
    blockArg.body.packets.len.toBinary(INT_LEN)

  for packet in blockArg.body.packets:
    result &= packet.serialize()

  result &= blockArg.body.elements.len.toBinary(INT_LEN)
  for elem in blockArg.body.elements:
    result &= elem.serializeContents()

  result &= blockArg.body.aggregate.serialize()

  for holder in blockArg.body.removals:
    result &= holder.toBinary(NICKNAME_LEN)
