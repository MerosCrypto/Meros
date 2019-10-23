#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Hash lib.
import ../../../../../lib/Hash

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#Element lib.
import ../../../../Consensus/Elements/Element

#Block lib.
import ../../../../Merit/Block

#Serialization libs.
import ../../../../../Network/Serialize/SerializeCommon
import ../../../../../Network/Serialize/Merit/SerializeBlockHeader

import ../../../../../Network/Serialize/Consensus/SerializeVerification
import ../../../../../Network/Serialize/Consensus/SerializeVerificationPacket
import ../../../../../Network/Serialize/Consensus/SerializeMeritRemoval

#Serialize a Block.
proc serialize*(
    blockArg: Block
): string {.forceCheck: [].} =
    result =
        blockArg.header.serialize() &
        blockArg.body.significant.toBinary().pad(INT_LEN) &
        blockArg.body.sketchSalt.pad(INT_LEN) &
        blockArg.body.packets.len.toBinary().pad(INT_LEN)

    for packet in blockArg.body.packets:
        result &= packet.serialize()

    result &= blockArg.body.elements.len.toBinary().pad(INT_LEN)
    for elem in blockArg.body.elements:
        case elem:
            of MeritRemoval as _:
                result &= char(MERIT_REMOVAL_PREFIX)
            else:
                doAssert(false, "serialize(BlockBody) tried to serialize an unsupported Element.")
        result &= elem.serialize()

    result &= blockArg.body.aggregate.toString()
