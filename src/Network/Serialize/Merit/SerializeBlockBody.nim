#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#BlockBody object.
import ../../../Database/Merit/objects/BlockBodyObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Serialize Element libs.
import ../Consensus/SerializeVerification
import ../Consensus/SerializeMeritRemoval

#Serialize a Block.
proc serialize*(
    body: BlockBody
): string {.forceCheck: [].} =
    result = body.transactions.len.toBinary().pad(INT_LEN)
    for tx in body.transactions:
        result &= tx.toString()
    result &= body.elements.len.toBinary().pad(INT_LEN)
    for elem in body.elements:
        result &= elem.serialize()
    result &= body.aggregate.toString()
