#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Merkle lib.
import ../../../lib/Merkle

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#BlockHeader object.
import ../../../Database/Merit/objects/BlockHeaderObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Block Header.
func serializeHash*(
    header: BlockHeader
): string {.inline, forceCheck: [].} =
    header.version.toBinary().pad(INT_LEN) &
    header.last.toString() &
    header.contents.toString() &

    header.significant.toBinary().pad(NICKNAME_LEN) &
    header.sketchSalt.pad(INT_LEN) &
    header.sketchCheck.toString() &

    (
        if header.newMiner: '\1' & header.minerKey.toString() else: '\0' & header.minerNick.toBinary().pad(NICKNAME_LEN)
    ) &
    header.time.toBinary().pad(INT_LEN)

func serialize*(
    header: BlockHeader
): string {.inline, forceCheck: [].} =
    header.serializeHash() &
    header.proof.toBinary().pad(INT_LEN) &
    header.signature.toString()
