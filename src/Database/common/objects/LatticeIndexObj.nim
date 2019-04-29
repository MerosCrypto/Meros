#Errors lib.
import ../../../lib/Errors

#Finals lib.
import finals

finalsd:
    #LatticeIndex object. Specifies a position on the Lattice.
    type LatticeIndex* = object
        address* {.final.}: string
        nonce* {.final.}: int

#Constructor.
func newLatticeIndex*(
    address: string,
    nonce: Natural
): LatticeIndex {.forceCheck: [].} =
    result = LatticeIndex(
        address: address,
        nonce: nonce
    )
    result.ffinalizeAddress()
    result.ffinalizeNonce()
