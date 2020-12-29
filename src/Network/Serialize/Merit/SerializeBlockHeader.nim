import ../../../lib/[Errors, Hash]
import ../../../Wallet/MinerWallet

import ../../../Database/Merit/objects/BlockHeaderObj

import ../SerializeCommon

proc serializeTemplate*(
  header: BlockHeader,
  packets: uint32
): string {.inline, forceCheck: [].} =
  header.version.toBinary(INT_LEN) &
  header.last.serialize() &
  header.contents.serialize() &

  packets.toBinary(INT_LEN) &
  header.sketchSalt.pad(INT_LEN) &
  header.sketchCheck.serialize() &

  (
    if header.newMiner: '\1' & header.minerKey.serialize() else: '\0' & header.minerNick.toBinary(NICKNAME_LEN)
  ) &
  header.time.toBinary(INT_LEN)

proc serializeHash*(
  header: BlockHeader,
  packets: uint32
): string {.inline, forceCheck: [].} =
  header.serializeTemplate(packets) &
  header.proof.toBinary(INT_LEN)

proc serialize*(
  header: BlockHeader,
  packets: uint32
): string {.inline, forceCheck: [].} =
  header.serializeHash(packets) &
  header.signature.serialize()
