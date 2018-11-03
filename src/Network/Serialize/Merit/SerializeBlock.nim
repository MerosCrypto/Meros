#Util lib.
import ../../../lib/Util

#Base lib.
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Merit objects.
import ../../../Database/Merit/objects/VerificationsObj
import ../../../Database/Merit/objects/BlockHeaderObj
import ../../../Database/Merit/objects/MinersObj
import ../../../Database/Merit/objects/BlockObj

#Serialize/Deserialize functions.
import ../SerializeCommon
import SerializeBlockHeader
import SerializeVerifications
import SerializeMiners

#String utils standard lib.
import strutils

#Serialize a Block.
func serialize*(blockArg: Block): string {.raises: [].} =
    #Create the serialized Block.
    result =
        !blockArg.header.serialize() &
        !blockArg.proof.toBinary() &
        !blockArg.verifications.serialize() &
        !blockArg.miners.serialize()
