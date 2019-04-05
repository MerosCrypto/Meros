#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Merkle lib.
import ../../../lib/Merkle

#BLS lib.
import ../../../lib/BLS

#BlockHeader object.
import ../../../Database/Merit/objects/BlockHeaderObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Block Header.
func serialize*(header: BlockHeader): string {.raises: [].} =
    result =
        header.nonce.toBinary().pad(INT_LEN) &
        header.last.toString() &
        header.verifications.toString() &
        header.miners.toString() &
        header.time.toBinary().pad(INT_LEN) &
        header.proof.toBinary().pad(INT_LEN)
