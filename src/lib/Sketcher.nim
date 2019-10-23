#Errors lib.
import Errors

#Hash lib.
import Hash

#VerificationPacket object.
import ../Database/Consensus/Elements/objects/VerificationPacketObj

#SerializeCommon lib.
import ../Network/Serialize/SerializeCommon

#Serialize Verification Packet lib.
import ../Network/Serialize/Consensus/SerializeVerificationPacket

#Minisketch lib.
import mc_minisketch

#Tables standard lib.
import tables

#The fact these need to be exported is bullshit. Thanks to ForceCheck, something happens somewhere.
#I honestly don't know the full info. ForceCheck errors on BlockBody.serialize() which doesn't need either of these.
#It just calls a function in this file which uses the function that returns these.
#That said, I'd rather export these than remove ForceCheck.
#-- Luke Parker
export Sketch, Table

type
    #SketchElement. Includes both the packet and its significance.
    SketchElement = object
        packet: VerificationPacket
        significance: int

    #Sketcher. Just a seq of SketchElements.
    Sketcher* = seq[SketchElement]

    #SketchResult. List of Elements in both sketches and the missing hashes.
    SketchResult* = object
        packets*: seq[VerificationPacket]
        missing*: seq[uint64]

#Convert a VerificationPacket hash into something sketchable.
proc sketchHash*(
    packet: VerificationPacket,
    salt: string
): uint64 {.inline, forceCheck: [].} =
    Blake64(salt & packet.serialize())

#Constructor.
proc newSketcher*(
    packets: seq[VerificationPacket] = @[]
): Sketcher {.forceCheck: [].} =
    result = @[]
    for packet in packets:
        result.add(SketchElement(
            packet: packet,
            significance: 0
        ))

#Add a packet.
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
        hashes: Table[uint64, bool] = initTable[uint64, bool]()
        hash: uint64

    for elem in sketcher:
        #Hash the packet.
        hash = elem.packet.sketchHash(salt)

        #If there's a collision, return false.
        if hashes.hasKey(hash):
            return false
        hashes[hash] = true

#Convert a Sketcher to a Sketch.
proc toSketch(
    sketcher: Sketcher,
    capacity: int,
    significant: int,
    salt: string
): tuple[
    sketch: Sketch,
    hashes: Table[uint64, int]
] {.forceCheck: [
    ValueError
].} =
    #Create the sketch.
    result.sketch = newSketch(64, 0, capacity)
    result.hashes = initTable[uint64, int]()

    var hash: uint64
    for e in 0 ..< sketcher.len:
        #If it's significant, use it.
        if sketcher[e].significance >= significant:
            #Hash the packet.
            hash = sketcher[e].packet.sketchHash(salt)
            #If there's a collision, throw.
            if result.hashes.hasKey(hash):
                raise newException(ValueError, "Collision found while sketching values.")

            result.sketch.add(hash)
            result.hashes[hash] = e

#Serialize a sketcher's sketch.
proc serialize*(
    sketcher: Sketcher,
    capacity: int,
    significant: int,
    salt: string
): string {.forceCheck: [
    ValueError
].} =
    if capacity == 0:
        return ""

    try:
        result = sketcher.toSketch(capacity, significant, salt).sketch.serialize()
    except ValueError as e:
        fcRaise e

#Merge two sketches and return the shared/missing packets.
proc merge*(
    sketcher: Sketcher,
    other: string,
    capacity: int,
    significant: int,
    salt: string
): SketchResult {.forceCheck: [
    ValueError
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
    except ValueError as e:
        fcRaise e
    #Merge the sketches.
    sketch.sketch.merge(other)

    #Get the differences.
    try:
        result.missing = sketch.sketch.decode()
    except ValueError as e:
        fcRaise e

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
                doAssert(false, "Couldn't get the index a hash maps to despite checking with hasKey first: " & e.msg)
            result.missing.delete(m)
            inc(offset)
            continue
        inc(m)

    #This does error on any collision, except if one of our Elements collides with an Element in the Sketch we don't have.
    #This must be handled via the Merkle.
