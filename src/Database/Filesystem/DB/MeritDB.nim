#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Difficulty, BlockHeader, and Block objects.
import ../../Merit/objects/DifficultyObj
import ../../Merit/objects/BlockHeaderObj
import ../../Merit/objects/BlockObj

#Serialization libs.
import Serialize/Merit/SerializeDifficulty
import Serialize/Merit/SerializeBlock

import Serialize/Merit/ParseDifficulty
import Serialize/Merit/ParseBlockHeader
import Serialize/Merit/ParseBlock

#DB object.
import objects/DBObj
export DBObj

proc save*(
    db: DB,
    difficulty: Difficulty
) {.forceCheck: [].} =
    discard

proc save*(
    db: DB,
    header: BlockHeader
) {.forceCheck: [].} =
    discard

proc save*(
    db: DB,
    blockArg: Block
) {.forceCheck: [].} =
    discard

proc saveTip*(
    db: DB,
    hash: Hash[384]
) {.forceCheck: [].} =
    discard

proc saveLiveMerit*(
    db: DB,
    merit: int
) {.forceCheck: [].} =
    discard

proc save*(
    db: DB,
    holder: string,
    merit: int
) {.forceCheck: [].} =
    discard

proc saveHolderEpoch*(
    db: DB,
    holder: BLSPublicKey,
    epoch: int
) {.forceCheck: [].} =
    discard

proc loadDifficulty*(
    db: DB
): Difficulty {.forceCheck: [].} =
    discard

proc loadBlockHeader*(
    db: DB,
    hash: Hash[384]
): BlockHeader {.forceCheck: [].} =
    discard

proc loadBlock*(
    db: DB,
    hash: Hash[384]
): Block {.forceCheck: [].} =
    discard

proc loadTip*(
    db: DB
): Hash[384] {.forceCheck: [].} =
    discard

proc loadLiveMerit*(
    db: DB
): int {.forceCheck: [].} =
    discard

proc loadHolders*(
    db: DB
): seq[string] {.forceCheck: [].} =
    discard

proc loadMerit*(
    db: DB,
    key: string
): int {.forceCheck: [].} =
    discard

proc loadHolderEpoch*(
    db: DB,
    holder: string
): int {.forceCheck: [].} =
    discard

proc commit*(
    db: DB
) {.forceCheck: [].} =
    discard
