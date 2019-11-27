#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element libs.
import ../../../Database/Consensus/Elements/Elements

#BlockBody object.
import ../../../Database/Merit/objects/BlockBodyObj

#SketchyBlock object.
import ../../objects/SketchyBlockObj

#Deserialize/parse functions.
import ../SerializeCommon

#Parse BlockElement lib.
import ../Consensus/ParseBlockElement

#Parse a BlockBody.
proc parseBlockBody*(
    bodyStr: string
): SketchyBlockBody {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Capacity | Sketch | Amount of Elements | Elements | Aggregate Signature
    result.capacity = bodyStr[0 ..< INT_LEN].fromBinary()
    var
        sketchLen: int = result.capacity * SKETCH_HASH_LEN
        sketchStart: int = INT_LEN
        elementsStart: int = sketchStart + sketchLen

        pbeResult: tuple[
            element: BlockElement,
            len: int
        ]
        i: int = elementsStart + INT_LEN
        elements: seq[BlockElement] = @[]

        aggregate: BLSSignature

    if bodyStr.len < i:
        raise newException(ValueError, "parseBlockBody not handed enough data to get the amount of Sketches/Elements.")

    result.sketch = bodyStr[sketchStart ..< elementsStart]

    for e in 0 ..< bodyStr[elementsStart ..< i].fromBinary():
        try:
            pbeResult = bodyStr.parseBlockElement(i)
        except ValueError as e:
            fcRaise e
        except BLSError as e:
            fcRaise e
        i += pbeResult.len
        elements.add(pbeResult.element)

    if bodyStr.len < i + BLS_SIGNATURE_LEN:
        raise newException(ValueError, "parseBlockBody not handed enough data to get the aggregate signature.")

    try:
        aggregate = newBLSSignature(bodyStr[i ..< i + BLS_SIGNATURE_LEN])
    except BLSError as e:
        fcRaise e

    result.data = newBlockBodyObj(
        @[],
        elements,
        aggregate
    )
