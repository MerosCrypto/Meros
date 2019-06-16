#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib (for BLSSignature).
import ../../../Wallet/MinerWallet

#Block Header lib.
import ../BlockHeader

#Block Body object.
import BlockBodyObj
export BlockBodyObj

#MeritHolderRecord and Miners objects.
import ../../common/objects/MeritHolderRecordObj
import MinersObj

#Finals lib.
import finals

#Block class.
type Block* = object
    #Block Header.
    header*: BlockHeader
    #Block Body.
    body*: BlockBody

#Nonce getter.
proc nonce*(
    blockArg: Block
): int {.inline, forceCheck: [].} =
    blockArg.header.nonce

#Hash getter.
proc hash*(
    blockArg: Block
): Hash[384] {.inline, forceCheck: [].} =
    blockArg.header.hash

#Records getter.
proc records*(
    blockArg: Block
): seq[MeritHolderRecord] {.inline, forceCheck: [].} =
    blockArg.body.records

#Miners getter.
proc miners*(
    blockArg: Block
): Miners {.inline, forceCheck: [].} =
    blockArg.body.miners

#Miners setter.
proc `miners=`*(
    blockArg: var Block,
    miners: Miners
) {.forceCheck: [].} =
    blockArg.miners = miners
    blockArg.header.miners = miners.merkle.hash

#Constructor.
func newBlockObj*(
    nonce: Natural,
    last: ArgonHash,
    aggregate: BLSSignature,
    records: seq[MeritHolderRecord],
    miners: Miners,
    time: uint32 = getTime(),
    proof: uint32 = 0
): Block {.forceCheck: [
    ArgonError
].} =
    #Create the Block Header.
    var header: BlockHeader
    try:
        header = newBlockHeader(
            nonce,
            last,
            aggregate,
            miners.merkle.hash,
            time,
            proof
        )
    except ArgonError as e:
        fcRaise e

    #Create the Block.
    result = Block(
        header: header,
        body: newBlockBodyObj(
            records,
            miners
        )
    )

func newBlockObj*(
    header: BlockHeader,
    body: BlockBody
): Block {.inline, forceCheck: [].} =
    Block(
        header: header,
        body: body
    )
