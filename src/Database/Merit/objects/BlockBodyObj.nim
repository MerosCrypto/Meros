#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element lib.
import ../../Consensus/Elements/Element

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
