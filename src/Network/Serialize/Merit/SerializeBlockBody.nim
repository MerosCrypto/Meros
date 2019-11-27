#Errors lib.
import ../../../lib/Errors

#Sketcher lib.
import ../../../lib/Sketcher

import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element lib.
import ../../../Database/Consensus/Elements/Element

#BlockBody object.
import ../../../Database/Merit/objects/BlockBodyObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Serialize Element libs.
import ../Consensus/SerializeVerification
import ../Consensus/SerializeMeritRemoval

#Serialize a Block.
proc serialize*(
    body: BlockBody,
    sketchSalt: string,
    capacityArg: int = 0
): string {.forceCheck: [
    ValueError
].} =
    var capacity: int = capacityArg
    if (capacity == 0) and (body.packets.len != 0):
        capacity = body.packets.len div 5 + 1

    result = capacity.toBinary(INT_LEN)

    try:
        result &= newSketcher(body.packets).serialize(
            capacity,
            0,
            sketchSalt
        )
    except SaltError as e:
        raise newException(ValueError, "BlockBody's elements have a collision with the specified sketchSalt: " & e.msg)

    result &= body.elements.len.toBinary(INT_LEN)
    for elem in body.elements:
        case elem:
            of MeritRemoval as _:
                result &= char(MERIT_REMOVAL_PREFIX)
            else:
                doAssert(false, "serialize(BlockBody) tried to serialize an unsupported Element.")
        result &= elem.serialize()

    result &= body.aggregate.toString()
