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
    #List of Transactions which have new/updated Verification Packets.
    transactions*: seq[Hash[384]]
    #Elements included in this Block.
    elements*: seq[BlockElement]
    #Aggregate signature.
    aggregate*: BLSSignature

#Constructor.
func newBlockBodyObj*(
    transactions: seq[Hash[384]],
    elements: seq[BlockElement],
    aggregate: BLSSignature
): BlockBody {.inline, forceCheck: [].} =
    BlockBody(
        transactions: transactions,
        elements: elements,
        aggregate: aggregate
    )
