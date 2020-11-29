import ../../../lib/[Errors, Util]

import ../BlockHeader
export BlockHeader

import BlockBodyObj
export BlockBodyObj

type Block* = object
  header*: BlockHeader
  body*: BlockBody

proc newBlockObj*(
  header: BlockHeader,
  body: BlockBody
): Block {.inline, forceCheck: [].} =
  Block(
    header: header,
    body: body
  )
