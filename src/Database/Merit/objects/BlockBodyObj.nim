#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element libs.
import ../../Consensus/Elements/Elements

#BlockBody object.
type BlockBody* = object
    #Hash of the packets side of the content Merkle.
    packetsContents*: Hash[256]
    #Packets for those Transactions.
    packets*: seq[VerificationPacket]
    #Elements included in this Block.
    elements*: seq[BlockElement]
    #Aggregate signature.
    aggregate*: BLSSignature

#Constructor.
func newBlockBodyObj*(
    packetsContents: Hash[256],
    packets: seq[VerificationPacket],
    elements: seq[BlockElement],
    aggregate: BLSSignature
): BlockBody {.inline, forceCheck: [].} =
    BlockBody(
        packetsContents: packetsContents,
        packets: packets,
        elements: elements,
        aggregate: aggregate
    )
