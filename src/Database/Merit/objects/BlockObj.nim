#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element lib.
import ../../Consensus/Elements/Element

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
    version: uint32,
    last: ArgonHash,
    contents: Hash[384],
    verifiers: Hash[384],
    miner: BLSPublicKey,
    significant: int,
    sketchSalt: string,
    transactions: seq[Hash[384]],
    packets: seq[VerificationPacket],
    elements: seq[BlockElement],
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
            significant,
            sketchSalt,
            transactions,
            packets,
            elements,
            aggregate
        )
    )

func newBlockObj*(
    version: uint32,
    last: ArgonHash,
    contents: Hash[384],
    verifiers: Hash[384],
    miner: uint16,
    significant: int,
    sketchSalt: string,
    transactions: seq[Hash[384]],
    packets: seq[VerificationPacket],
    elements: seq[BlockElement],
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
            significant,
            sketchSalt,
            transactions,
            packets,
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

#Hash getter.
proc hash*(
    blockArg: Block
): Hash[384] {.inline, forceCheck: [].} =
    blockArg.header.hash
