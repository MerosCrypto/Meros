#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element libs.
import ../../Consensus/Elements/Elements

#Block Header lib.
import ../BlockHeader
export BlockHeader

#Block Body object.
import BlockBodyObj
export BlockBodyObj

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
    significant: uint16,
    sketchSalt: string,
    sketchCheck: Hash[384],
    miner: BLSPublicKey,
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
            significant,
            sketchSalt,
            sketchCheck,
            miner,
            time,
            proof,
            signature
        ),
        body: newBlockBodyObj(
            packets,
            elements,
            aggregate
        )
    )

func newBlockObj*(
    version: uint32,
    last: ArgonHash,
    contents: Hash[384],
    significant: uint16,
    sketchSalt: string,
    sketchCheck: Hash[384],
    miner: uint16,
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
            significant,
            sketchSalt,
            sketchCheck,
            miner,
            time,
            proof,
            signature
        ),
        body: newBlockBodyObj(
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
