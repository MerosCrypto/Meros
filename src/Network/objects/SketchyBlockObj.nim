import ../../lib/Errors

import ../../Database/Merit/[BlockHeader, Block]
import ../../Database/Merit/Block

#Types for partial BlockBody/Block data combined with the matching sketches.
type
  SketchyBlockBody* = object
    data*: BlockBody
    capacity*: int
    sketch*: string

  SketchyBlock* = object
    data*: Block
    capacity*: int
    sketch*: string

proc newSketchyBlockObj*(
  header: BlockHeader,
  body: SketchyBlockBody
): SketchyBlock {.inline, forceCheck: [].} =
  SketchyBlock(
    data: newBlockObj(header, body.data),
    capacity: body.capacity,
    sketch: body.sketch
  )
