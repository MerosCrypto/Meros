import ../../../lib/[Errors, Hash]
import ../../../Wallet/MinerWallet

import ../../../Database/Merit/objects/BlockHeaderObj

import ../SerializeCommon

proc serializeTemplate*(
  header: BlockHeader,
): string {.inline, forceCheck: [].} =
  header.version.toBinary(INT_LEN) &
  header.last.serialize() &
  header.contents.serialize() &

  header.packetsQuantity.toBinary(INT_LEN) &
  header.sketchSalt.pad(INT_LEN) &
  header.sketchCheck.serialize() &

  (
    if header.newMiner: '\1' & header.minerKey.serialize() else: '\0' & header.minerNick.toBinary(NICKNAME_LEN)
  ) &
  header.time.toBinary(INT_LEN)

proc serializeHash*(
  header: BlockHeader
): string {.inline, forceCheck: [].} =
  header.serializeTemplate() &
  header.proof.toBinary(INT_LEN)

proc serialize*(
  header: BlockHeader
): string {.inline, forceCheck: [].} =
  header.serializeHash() &
  header.signature.serialize()
