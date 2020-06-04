import sets, tables

import mc_minisketch

import Errors, Hash

import ../Database/Consensus/Elements/objects/VerificationPacketObj
import ../Network/Serialize/Consensus/SerializeVerificationPacket

type
  SketchElement = object
    packet*: VerificationPacket
    significance*: int

  Sketcher* = seq[SketchElement]

  #SketchResult. List of Elements in both sketches and the missing hashes.
  SketchResult* = object
    packets*: seq[VerificationPacket]
    missing*: seq[uint64]

#Convert a VerificationPacket hash into something sketchable.
proc sketchHash*(
  salt: string,
  packet: VerificationPacket
): uint64 {.inline, forceCheck: [].} =
  Blake64(salt & packet.serialize())

proc newSketcher*(
  getMerit: proc (
    nick: uint16
  ): int {.gcsafe, raises: [].},
  isMalicious: proc (
    holder: uint16
  ): bool {.gcsafe, raises: [].},
  packets: seq[VerificationPacket]
): Sketcher {.forceCheck: [].} =
  result = @[]
  for packet in packets:
    var merit: int = 0
    for holder in packet.holders:
      if not holder.isMalicious:
        merit += getMerit(holder)

    result.add(SketchElement(
      packet: packet,
      significance: merit
    ))

proc newSketcher*(
  packets: seq[VerificationPacket]
): Sketcher {.forceCheck: [].} =
  result = @[]
  for packet in packets:
    result.add(SketchElement(
      packet: packet,
      significance: 0
    ))

proc add*(
  sketcher: var Sketcher,
  packet: VerificationPacket,
  significance: int
) {.forceCheck: [].} =
  sketcher.add(SketchElement(
    packet: packet,
    significance: significance
  ))

#Checks if the elements collide when the specified sketch salt is used.
proc collides*(
  sketcher: Sketcher,
  salt: string
): bool {.forceCheck: [].} =
  var
    hashes: HashSet[uint64] = initHashSet[uint64]()
    hash: uint64

  for elem in sketcher:
    #Hash the packet.
    hash = sketchHash(salt, elem.packet)

    #If there's a collision, return false.
    if hashes.contains(hash):
      return false
    hashes.incl(hash)

#Convert a Sketcher to a Sketch.
proc toSketch(
  sketcher: Sketcher,
  capacity: int,
  significant: uint16,
  salt: string
): tuple[
  sketch: Sketch,
  hashes: Table[uint64, int]
] {.forceCheck: [
  SaltError
].} =
  #Create the sketch.
  result.sketch = newSketch(64, 0, capacity)
  result.hashes = initTable[uint64, int]()

  var hash: uint64
  for e in 0 ..< sketcher.len:
    #If it's significant, use it.
    if sketcher[e].significance >= int(significant):
      #Hash the packet.
      hash = sketchHash(salt, sketcher[e].packet)
      #If there's a collision, throw.
      if result.hashes.hasKey(hash):
        raise newLoggedException(SaltError, "Collision found while sketching values.")

      result.sketch.add(hash)
      result.hashes[hash] = e

#Serialize a sketcher's sketch.
proc serialize*(
  sketcher: Sketcher,
  capacity: int,
  significant: uint16,
  salt: string
): string {.forceCheck: [
  SaltError
].} =
  if capacity == 0:
    return ""

  try:
    result = sketcher.toSketch(capacity, significant, salt).sketch.serialize()
  except SaltError as e:
    raise e

#Merge two sketches and return the shared/missing packets.
proc merge*(
  sketcher: Sketcher,
  other: string,
  capacity: int,
  significant: uint16,
  salt: string
): SketchResult {.forceCheck: [
  ValueError,
  SaltError
].} =
  if capacity == 0:
    return

  #Get the sketch and the hashes of every packet.
  var sketch: tuple[
    sketch: Sketch,
    hashes: Table[uint64, int]
  ]
  try:
    sketch = sketcher.toSketch(capacity, significant, salt)
  except SaltError as e:
    raise e
  #Merge the sketches.
  sketch.sketch.merge(other)

  #Get the differences.
  try:
    result.missing = sketch.sketch.decode()
  except ValueError as e:
    raise e

  #The packets are every packet in our sketcher, minus packets which showed up as a difference.
  result.packets = @[]
  for e in sketcher:
    result.packets.add(e.packet)

  #Iterate over the differences.
  var
    m: int = 0
    offset: int = 0
  while m < result.missing.len:
    #If we have one of the differences, remove it from both packets and missing.
    if sketch.hashes.hasKey(result.missing[m]):
      try:
        result.packets.delete(sketch.hashes[result.missing[m]] - offset)
      except KeyError as e:
        panic("Couldn't get the index a hash maps to despite checking with hasKey first: " & e.msg)
      result.missing.delete(m)
      inc(offset)
      continue
    inc(m)

  #This does error on any collision, except if one of our Elements collides with an Element in the Sketch we don't have.
  #This must be handled via the Merkle.
