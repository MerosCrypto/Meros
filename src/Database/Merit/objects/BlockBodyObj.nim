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
    #Amount of Merit required for a Transaction to be included.
    significant*: int
    #Salt used when hasing sketch elements in order to avoid collisions.
    sketchSalt*: string
    #Packets for those Transactions.
    packets*: seq[VerificationPacket]
    #Elements included in this Block.
    elements*: seq[BlockElement]
    #Aggregate signature.
    aggregate*: BLSSignature

#Constructor.
func newBlockBodyObj*(
    significant: int,
    sketchSalt: string,
    packets: seq[VerificationPacket],
    elements: seq[BlockElement],
    aggregate: BLSSignature
): BlockBody {.inline, forceCheck: [].} =
    BlockBody(
        significant: significant,
        sketchSalt: sketchSalt,
        packets: packets,
        elements: elements,
        aggregate: aggregate
    )
