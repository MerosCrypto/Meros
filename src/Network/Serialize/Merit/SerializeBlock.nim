#Block lib.
import ../../../Database/Merit/Block

#Serialize/Deserialize functions.
import ../SerializeCommon
import SerializeBlockHeader
import SerializeVerifications
import SerializeMiners

#Serialize a Block.
proc serialize*(blockArg: Block): string {.raises: [].} =
    #Create the serialized Block.
    var
        header: string = blockArg.header.serialize()
        verifications: string = blockArg.verifications.serialize()
        miners: string = blockArg.miners.serialize()

    result =
        header.lenPrefix & header &
        verifications.lenPrefix & verifications &
        miners.lenPrefix & miners
