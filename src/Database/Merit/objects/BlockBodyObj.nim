import ../../../lib/[Errors, Hash]
import ../../../Wallet/MinerWallet

import ../../Consensus/Elements/Elements

#Turned into a ref due to a problem with the aggregate signature dropping.
type BlockBody* = ref object
  #Hash of the packets side of the content Merkle.
  packetsContents*: Hash[256]
  #Packets for those Transactions.
  packets*: seq[VerificationPacket]
  #Elements included in this Block.
  elements*: seq[BlockElement]
  #Aggregate signature.
  aggregate*: BLSSignature

  #Merit Removals. Internal footnote.
  removals*: set[uint16]

func newBlockBodyObj*(
  packetsContents: Hash[256],
  packets: seq[VerificationPacket],
  elements: seq[BlockElement],
  aggregate: BLSSignature,
  removals: set[uint16]
): BlockBody {.inline, forceCheck: [].} =
  BlockBody(
    packetsContents: packetsContents,
    packets: packets,
    elements: elements,
    aggregate: aggregate,
    removals: removals
  )
