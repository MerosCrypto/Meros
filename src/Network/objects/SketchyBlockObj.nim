#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#VerificationPacket object.
import ../../Database/Consensus/Elements/VerificationPacket

#BlockHeader/Block libs.
import ../../Database/Merit/BlockHeader
import ../../Database/Merit/Block

#Algorithm standard lib (used to sort Verification Packets).
import algorithm

#Type for partial BlockBody/Block data and the matching sketches.
type
    SketchyBlockBody* = object
        data*: BlockBody
        capacity*: int
        sketch*: string

    SketchyBlock* = object
        data*: Block
        capacity*: int
        sketch*: string

proc newSketchyBlockBodyObj*(
    body: BlockBody,
    capacity: int,
    sketch: string
): SketchyBlockBody {.inline, forceCheck: [].} =
    SketchyBlockBody(
        data: body,
        capacity: capacity,
        sketch: sketch
    )

proc newSketchyBlockObj*(
    header: BlockHeader,
    body: SketchyBlockBody
): SketchyBlock {.inline, forceCheck: [].} =
    SketchyBlock(
        data: newBlockObj(header, body.data),
        capacity: body.capacity,
        sketch: body.sketch
    )
