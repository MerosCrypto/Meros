#Util lib.
import ../../../lib/Util

#Base lib.
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Verifications lib.
import ../../../Database/Verifications/Verifications

#Merit objects.
import ../../../Database/Merit/objects/BlockHeaderObj
import ../../../Database/Merit/objects/MinersObj
import ../../../Database/Merit/objects/BlockObj

#Serialize/Deserialize functions.
import ../SerializeCommon
import SerializeBlockHeader
import ../Verifications/SerializeVerifications
import SerializeMiners

#String utils standard lib.
import strutils

#Serialize a Block.
proc serialize*(blockArg: Block, verifs: Verifications): string {.raises: [KeyError].} =
    #Create the serialized Block.
    result =
        !blockArg.header.serialize() &
        !blockArg.verifications.serialize(verifs) &
        !blockArg.miners.serialize()
