import ../../../lib/[Errors, Hash]
import ../../../Wallet/MinerWallet

import ../../../Database/Consensus/Elements/Elements
import ../../../Database/Merit/objects/BlockBodyObj

import ../../objects/SketchyBlockObj

import ../SerializeCommon
import ../Consensus/ParseBlockElement

proc parseBlockBody*(
  bodyStr: string
): SketchyBlockBody {.forceCheck: [
  ValueError
].} =
  #Packets Contents | Capacity | Sketch | Amount of Elements | Elements | Aggregate Signature
  result.capacity = bodyStr[HASH_LEN ..< HASH_LEN + INT_LEN].fromBinary()
  var
    sketchLen: int = result.capacity * SKETCH_HASH_LEN
    sketchStart: int = HASH_LEN + INT_LEN
    elementsStart: int = sketchStart + sketchLen

    pbeResult: tuple[
      element: BlockElement,
      len: int
    ]
    i: int = elementsStart + INT_LEN
    elements: seq[BlockElement] = @[]

    aggregate: BLSSignature

  if bodyStr.len < i:
    raise newLoggedException(ValueError, "parseBlockBody not handed enough data to get the amount of Sketches/Elements.")

  result.sketch = bodyStr[sketchStart ..< elementsStart]

  for e in 0 ..< bodyStr[elementsStart ..< i].fromBinary():
    try:
      pbeResult = bodyStr.parseBlockElement(i)
    except ValueError as e:
      raise e
    i += pbeResult.len
    elements.add(pbeResult.element)

  if bodyStr.len < i + BLS_SIGNATURE_LEN:
    raise newLoggedException(ValueError, "parseBlockBody not handed enough data to get the aggregate signature.")

  try:
    aggregate = newBLSSignature(bodyStr[i ..< i + BLS_SIGNATURE_LEN])
  except BLSError:
    raise newLoggedException(ValueError, "Invalid aggregate signature.")

  result.data = newBlockBodyObj(
    bodyStr[0 ..< HASH_LEN].toHash[:256](),
    @[],
    elements,
    aggregate
  )
