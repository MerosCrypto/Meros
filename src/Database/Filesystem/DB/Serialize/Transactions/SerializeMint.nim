#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Mint object.
import ../../../../Transactions/objects/MintObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Serialize Mint lib.
import SerializeMintOutput

#Serialization functions.
proc serialize*(
    mint: Mint
): string {.inline, forceCheck: [].} =
    result =
        mint.nonce.toBinary().pad(INT_LEN) &
        cast[MintOutput](mint.outputs[0]).serialize()

proc serializeHash*(
    mint: Mint
): string {.forceCheck: [].} =
    result =
        "\0" &
        mint.serialize()
