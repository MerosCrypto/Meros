#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#Mint object.
import ../../../..//Transactions/objects/MintObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Serialization functions.
proc serializeHash*(
    mint: Mint
): string {.forceCheck: [].} =
    result =
        "\0" &
        mint.nonce.toBinary().pad(INT_LEN) &
        cast[MintOutput](mint.outputs[0]).key.toString() &
        mint.outputs[0].amount.toBinary().pad(MEROS_LEN)

proc serialize*(
    mint: Mint
): string {.inline, forceCheck: [].} =
    result =
        mint.nonce.toBinary().pad(INT_LEN) &
        cast[MintOutput](mint.outputs[0]).key.toString() &
        mint.outputs[0].amount.toBinary().pad(MEROS_LEN)
