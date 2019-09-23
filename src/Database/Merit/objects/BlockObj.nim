#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Block Header lib.
import ../BlockHeader
export BlockHeader

#Block Body object.
import BlockBodyObj
export BlockBodyObj

#Finals lib.
import finals

#Block class.
type Block* = object
    #Block Header.
    header*: BlockHeader
    #Block Body.
    body*: BlockBody

#Constructor.
func newBlockObj*(
    version: int,
    last: ArgonHash,
    contents: Hash[384],
    verifiers: Hash[384],
    miner: BLSPublicKey,
    transactions: seq[Hash[384]],
    elements: seq[Element],
    aggregate: BLSSignature,
    time: uint32 = getTime(),
    proof: uint32 = 0,
    signature: BLSSignature = nil
): Block {.inline, forceCheck: [].} =
    Block(
        header: newBlockHeader(
            version,
            last,
            contents,
            verifiers,
            miner,
            time,
            proof,
            signature
        ),
        body: newBlockBodyObj(
            transactions,
            elements,
            aggregate
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

#Converters to either the header or body.
converter toHeader*(
    blockArg: Block
): BlockHeader {.inline, forceCheck: [].} =
    blockArg.header

converter toBody*(
    blockArg: Block
): BlockBody {.inline, forceCheck: [].} =
    blockArg.body
