import ../../../lib/[Errors, Hash]

import ../../../Database/Merit/BlockHeader

import ../../objects/SketchyBlockObj

import ../SerializeCommon
import ParseBlockHeader, ParseBlockBody

proc parseBlock*(
  rx: RandomX,
  blockStr: string
): SketchyBlock {.forceCheck: [
  ValueError
].} =
  #Header | Body
  var
    header: BlockHeader
    body: SketchyBlockBody

  try:
    header = rx.parseBlockHeader(blockStr)
    body = blockStr.substr(
      BLOCK_HEADER_DATA_LEN +
      (if header.newMiner: BLS_PUBLIC_KEY_LEN else: NICKNAME_LEN) +
      INT_LEN + INT_LEN + BLS_SIGNATURE_LEN
    ).parseBlockBody()
  except ValueError as e:
    raise e

  #Create the SketchyBlock.
  result = newSketchyBlockObj(header, body)
