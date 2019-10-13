#Errors lib.
import ../../lib/Errors

#BlockHeader/Block libs.
import ../../Database/Merit/BlockHeader
import ../../Database/Merit/Block

#Type for partial BlockBody/Block data and the matching sketches.
type
    SketchyBlockBody* = object
        data*: BlockBody
        capacity*: int
        transactions*: string
        packets*: string

    SketchyBlock* = object
        data*: Block
        capacity*: int
        transactions*: string
        packets*: string

proc newSketchyBlockBodyObj*(
    body: BlockBody,
    capacity: int,
    transactions: string,
    packets: string
): SketchyBlockBody {.inline, forceCheck: [].} =
    SketchyBlockBody(
        data: body,
        capacity: capacity,
        transactions: transactions,
        packets: packets
    )

proc newSketchyBlockObj*(
    header: BlockHeader,
    body: SketchyBlockBody
): SketchyBlock {.inline, forceCheck: [].} =
    SketchyBlock(
        data: newBlockObj(header, body.data),
        capacity: body.capacity,
        transactions: body.transactions,
        packets: body.packets
    )
