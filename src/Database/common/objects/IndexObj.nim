#Finals lib.
import finals

finalsd:
    #Index object. Specifies a position on a Table of chains (Lattice or Verifications objects).
    type Index* = ref object of RootObj
        key* {.final.}: string #Key, as in Key/Value, not Public Key.
        nonce* {.final.}: uint

#Constructor.
func newIndex*(key: string, nonce: uint): Index {.raises: [].} =
    result = Index(
        key: key,
        nonce: nonce
    )
    result.ffinalizeKey()
    result.ffinalizeNonce()
