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
    #SketchElement. Includes both the element and its significance.
    SketchElement[T] = object
        element: T
        significance: int

    #Sketcher. Just a seq of SketchElements.
    Sketcher*[T] = seq[SketchElement[T]]

    #SketchResult. List of Elements in both sketches and the missing hashes.
    SketchResult*[T] = object
        elements*: seq[T]
        missing*: seq[uint64]

#Convert a Transaction hash into something sketchable.
proc sketchHash*(
    hash: Hash[384],
    salt: string
): uint64 {.inline, forceCheck: [].} =
    Blake64(salt & hash.toString())

#Convert a VerificationPacket hash into something sketchable.
proc sketchHash*(
    packet: VerificationPacket,
    salt: string
): uint64 {.inline, forceCheck: [].} =
    Blake64(salt & packet.serialize())

#Constructor.
proc newSketcher*[T](
    elements: seq[T] = @[]
): Sketcher[T] {.forceCheck: [].} =
    result = @[]
    for element in elements:
        result.add(SketchElement[T](
            element: element,
            significance: 0
        ))

#Add an element.
proc add*[T](
    sketcher: Sketcher[T],
    elem: T,
    significance: int
) {.forceCheck: [].} =
    sketcher.add(SketchElement(
        element: elem,
        significance: significance
    ))

#Convert a Sketcher to a Sketch.
proc toSketch[T](
    sketcher: Sketcher[T],
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
            #Hash the element.
            hash = sketcher[e].element.sketchHash(salt)
            #If there's a collision, throw.
            if result.hashes.hasKey(hash):
                raise newException(ValueError, "Collision found while sketching values.")

            result.sketch.add(hash)
            result.hashes[hash] = e

#Serialize a sketcher's sketch.
proc serialize*[T](
    sketcher: Sketcher[T],
    capacity: int,
    significant: int,
    salt: string
): string {.forceCheck: [
    ValueError
].} =
    if capacity == 0:
        return ""

    try:
        sketcher.toSketch(capacity, significant, salt).sketch.serialize()
    except ValueError as e:
        fcRaise e

#Merge two sketches and return the shared/missing elements.
proc merge*[T](
    sketcher: Sketcher[T],
    other: string,
    capacity: int,
    significant: int,
    salt: string
): SketchResult[T] {.forceCheck: [
    ValueError
].} =
    if capacity == 0:
        return

    #Get the sketch and the hashes of every element.
    var sketch: tuple[
        sketch: Sketch,
        hashes: Table[uint64, int]
    ] = sketcher.toSketch(capacity, significant, salt)
    #Merge the sketches.
    sketch.sketch.merge(other)

    #Get the differences.
    try:
        result.missing = sketch.sketch.decode()
    except ValueError as e:
        fcRaise e

    #The elements are every element in our sketcher, minus elements which showed up as a difference.
    result.elements = @[]
    for e in sketcher:
        result.elements.add(e.element)

    #Iterate over the differences.
    var
        m: int = 0
        offset: int = 0
    while m < result.missing.len:
        #If we have one of the differences, remove it from both elements and missing.
        if sketch.hashes.hasKey(result.missing[m]):
            try:
                result.elements.delete(sketch.hashes[result.missing[m]] - offset)
            except KeyError as e:
                doAssert(false, "Couldn't get the index a hash maps to despite checking with hasKey first: " & e.msg)
            result.missing.delete(m)
            inc(offset)
            continue
        inc(m)

    #This does error on any collision, except if one of our Elements collides with an Element in the Sketch we don't have.
    #This must be handled via the Merkle.
