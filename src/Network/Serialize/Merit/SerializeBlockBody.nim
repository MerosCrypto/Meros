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
    body: BlockBody
): string {.forceCheck: [
    ValueError
].} =
    var capacity: int = body.transactions.len div 5 + 1

    result =
        body.significant.toBinary().pad(INT_LEN) &
        body.sketchSalt.pad(INT_LEN) &
        capacity.toBinary().pad(INT_LEN)

    try:
        result &= newSketcher(body.transactions).serialize(
            capacity,
            0,
            body.sketchSalt
        )

        result &= newSketcher(body.packets).serialize(
            capacity,
            0,
            body.sketchSalt
        )
    except ValueError as e:
        raise newException(ValueError, "Sketches have a collision with the salt in the BlockBody: " & e.msg)

    result &= body.elements.len.toBinary().pad(INT_LEN)
    for elem in body.elements:
        case elem:
            of MeritRemoval as _:
                result &= char(MERIT_REMOVAL_PREFIX)
            else:
                doAssert(false, "serialize(BlockBody) tried to serialize an unsupported Element.")
        result &= elem.serialize()

    result &= body.aggregate.toString()
