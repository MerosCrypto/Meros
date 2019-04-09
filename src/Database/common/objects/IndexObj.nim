#Errors lib.
import ../../../lib/Errors

#Finals lib.
import finals

finalsd:
    #Index object. Specifies a position on a Block Lattice (Lattice or Verifications DAGs).
    type Index* = object of RootObj
        key* {.final.}: string #Key, as in Key/Value, not Public Key.
                               #Address on the Lattice/BLS Public Key on the Verifications DAG.
        nonce* {.final.}: uint

#Constructor.
func newIndex*(
    key: string,
    nonce: uint
): Index {.forceCheck: [].} =
    result = Index(
        key: key,
        nonce: nonce
    )
    result.ffinalizeKey()
    result.ffinalizeNonce()
