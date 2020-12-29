import ../../lib/Errors

import ../../Database/Merit/[BlockHeader, Block]
import ../../Database/Merit/Block

#Types for partial BlockBody/Block data combined with the matching sketches.
type
  SketchyBlockHeader* = object
    data*: BlockHeader
    packetsQuantity*: uint32

  SketchyBlockBody* = object
    data*: BlockBody
    capacity*: int
    sketch*: string

  SketchyBlock* = object
    data*: Block
    packetsQuantity*: uint32
    capacity*: int
    sketch*: string

proc newSketchyBlockHeaderObj*(
  header: BlockHeader,
  packetsQuantity: uint32
): SketchyBlockHeader {.inline, forceCheck: [].} =
  SketchyBlockHeader(
    data: header,
    packetsQuantity: packetsQuantity
  )

proc newSketchyBlockObj*(
  header: SketchyBlockHeader,
  body: SketchyBlockBody
): SketchyBlock {.inline, forceCheck: [].} =
  SketchyBlock(
    data: newBlockObj(header.data, body.data),
    packetsQuantity: header.packetsQuantity,
    capacity: body.capacity,
    sketch: body.sketch
  )
