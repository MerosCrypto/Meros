#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#BlockHeader object.
import ../../../Database/Merit/objects/BlockHeaderObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Block Header.
proc serializeTemplate*(
    header: BlockHeader
): string {.inline, forceCheck: [].} =
    header.version.toBinary(INT_LEN) &
    header.last.toString() &
    header.contents.toString() &

    header.significant.toBinary(NICKNAME_LEN) &
    header.sketchSalt.pad(INT_LEN) &
    header.sketchCheck.toString() &

    (
        if header.newMiner: '\1' & header.minerKey.serialize() else: '\0' & header.minerNick.toBinary(NICKNAME_LEN)
    ) &
    header.time.toBinary(INT_LEN)

proc serializeHash*(
    header: BlockHeader
): string {.inline, forceCheck: [].} =
    header.serializeTemplate() &
    header.proof.toBinary(INT_LEN)

proc serialize*(
    header: BlockHeader
): string {.inline, forceCheck: [].} =
    header.serializeHash() &
    header.signature.serialize()
