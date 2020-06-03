import ../../../lib/[Errors, Util, Hash]
import ../../../Wallet/MinerWallet

import ../../Consensus/Elements/Elements

import ../BlockHeader
export BlockHeader

import BlockBodyObj
export BlockBodyObj

type Block* = object
  #Block Header.
  header*: BlockHeader
  #Block Body.
  body*: BlockBody

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
