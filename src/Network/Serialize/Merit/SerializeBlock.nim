#Merit objects.
import ../../../Database/Merit/objects/BlockHeaderObj
import ../../../Database/Merit/objects/MinersObj
import ../../../Database/Merit/objects/BlockObj

#Serialize/Deserialize functions.
import ../SerializeCommon
import SerializeBlockHeader
import SerializeVerifications
import SerializeMiners

#Serialize a Block.
proc serialize*(blockArg: Block): string {.raises: [].} =
    #Create the serialized Block.
    result =
        !blockArg.header.serialize() &
        !blockArg.verifications.serialize() &
        !blockArg.miners.serialize()
