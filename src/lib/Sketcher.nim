import sets

import mc_minisketch

import Errors, Hash

import ../Database/Consensus/Elements/objects/VerificationPacketObj
import ../Network/Serialize/Consensus/SerializeVerificationPacket

#SketchResult. List of Elements in both sketches and the missing hashes.
type SketchResult* = object
  packets*: seq[VerificationPacket]
  missing*: seq[uint64]

#Convert a VerificationPacket hash into something sketchable.
proc sketchHash*(
  salt: string,
  packet: VerificationPacket
): uint64 {.inline, forceCheck: [].} =
  Blake64(salt & packet.serialize())

#Checks if the elements collide when the specified sketch salt is used.
proc collides*(
  sketcher: seq[VerificationPacket],
  salt: string
): bool {.forceCheck: [].} =
  var
    hashes: HashSet[uint64] = initHashSet[uint64]()
    hash: uint64

  for elem in sketcher:
    #Hash the packet.
    hash = sketchHash(salt, elem)

    #If there's a collision, return true.
    if hashes.contains(hash):
      return true
    hashes.incl(hash)

#Convert Packets to a Sketch.
proc toSketch(
  sketcher: seq[VerificationPacket],
  capacity: int,
  salt: string
): tuple[
  sketch: Sketch,
  hashes: HashSet[uint64]
] {.forceCheck: [
  SaltError
].} =
  #Create the sketch.
  result.sketch = newSketch(64, 0, csize_t(capacity))
  result.hashes = initHashSet[uint64]()

  var hash: uint64
  for e in 0 ..< sketcher.len:
    #Hash the packet.
    hash = sketchHash(salt, sketcher[e])
    #If there's a collision, throw.
    if result.hashes.contains(hash):
      raise newLoggedException(SaltError, "Collision found while sketching values.")

    result.sketch.add(hash)
    result.hashes.incl(hash)

#Serialize a sketcher's sketch.
proc serialize*(
  sketcher: seq[VerificationPacket],
  capacity: int,
  salt: string
): string {.forceCheck: [
  SaltError
].} =
  if capacity == 0:
    return ""

  try:
    result = sketcher.toSketch(capacity, salt).sketch.serialize()
  except SaltError as e:
    raise e

#Merge two sketches and return the shared/missing packets.
proc merge*(
  sketcher: seq[VerificationPacket],
  other: string,
  capacity: int,
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
    hashes: HashSet[uint64]
  ]
  try:
    sketch = sketcher.toSketch(capacity, salt)
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
    result.packets.add(e)

  #Iterate over the differences.
  var m: int = 0
  while m < result.missing.len:
    #If we have one of the differences, remove it from both packets and missing.
    if sketch.hashes.contains(result.missing[m]):
      for p in 0 ..< result.packets.len:
        if sketchHash(salt, result.packets[p]) == result.missing[m]:
          result.packets.del(p)
          result.missing.del(m)
          break
      continue
    inc(m)

  #This does error on any collision, except if one of our Elements collides with an Element in the Sketch we don't have.
  #This must be handled via the Merkle.
