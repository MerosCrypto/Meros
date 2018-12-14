#Finals lib.
import finals

finalsd:
    #Index object. Specifies a Entry on the Lattice.
    type Index* = ref object of RootObj
        address* {.final.}: string
        nonce* {.final.}: uint

#Construcor.
func newIndex*(address: string, nonce: uint): Index {.raises: [].} =
    result = Index(
        address: address,
        nonce: nonce
    )
    result.ffinalizeAddress()
    result.ffinalizeNonce()
