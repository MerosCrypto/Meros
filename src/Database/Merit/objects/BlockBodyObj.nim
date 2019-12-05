#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element libs.
import ../../Consensus/Elements/Elements

#BlockBody object.
type BlockBody* = object
    #Packets for those Transactions.
    packets*: seq[VerificationPacket]
    #Elements included in this Block.
    elements*: seq[BlockElement]
    #Aggregate signature.
    aggregate*: BLSSignature

#Constructor.
func newBlockBodyObj*(
    packets: seq[VerificationPacket],
    elements: seq[BlockElement],
    aggregate: BLSSignature
): BlockBody {.inline, forceCheck: [].} =
    BlockBody(
        packets: packets,
        elements: elements,
        aggregate: aggregate
    )
