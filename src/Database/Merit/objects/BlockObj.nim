#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element libs.
import ../../Consensus/Elements/Elements

#Block Header lib.
import ../BlockHeader
export BlockHeader

#Block Body object.
import BlockBodyObj
export BlockBodyObj

#Block class.
type Block* = object
  #Block Header.
  header*: BlockHeader
  #Block Body.
  body*: BlockBody

#Constructor.
proc newBlockObj*(
  version: uint32,
  last: RandomXHash,
  contents: Hash[256],
  significant: uint16,
  sketchSalt: string,
  sketchCheck: Hash[256],
  miner: BLSPublicKey,
  packetsContents: Hash[256],
  packets: seq[VerificationPacket],
  elements: seq[BlockElement],
  aggregate: BLSSignature,
  time: uint32 = getTime(),
  proof: uint32 = 0,
  signature: BLSSignature = newBLSSignature(),
  rx: RandomX = nil
): Block {.inline, forceCheck: [].} =
  Block(
    header: newBlockHeader(
      version,
      last,
      contents,
      significant,
      sketchSalt,
      sketchCheck,
      miner,
      time,
      proof,
      signature,
      rx
    ),
    body: newBlockBodyObj(
      packetsContents,
      packets,
      elements,
      aggregate
    )
  )

proc newBlockObj*(
  version: uint32,
  last: RandomXHash,
  contents: Hash[256],
  significant: uint16,
  sketchSalt: string,
  sketchCheck: Hash[256],
  miner: uint16,
  packetsContents: Hash[256],
  packets: seq[VerificationPacket],
  elements: seq[BlockElement],
  aggregate: BLSSignature,
  time: uint32 = getTime(),
  proof: uint32 = 0,
  signature: BLSSignature = newBLSSignature(),
  rx: RandomX = nil
): Block {.inline, forceCheck: [].} =
  Block(
    header: newBlockHeader(
      version,
      last,
      contents,
      significant,
      sketchSalt,
      sketchCheck,
      miner,
      time,
      proof,
      signature,
      rx
    ),
    body: newBlockBodyObj(
      packetsContents,
      packets,
      elements,
      aggregate
    )
  )

proc newBlockObj*(
  header: BlockHeader,
  body: BlockBody
): Block {.inline, forceCheck: [].} =
  Block(
    header: header,
    body: body
  )
