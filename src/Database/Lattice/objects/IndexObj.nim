#BN lib.
import BN

#Finals lib.
import finals

finalsd:
    #Index object. Specifies a Node on the Lattice.
    type Index* = ref object of RootObj
        address* {.final.}: string
        nonce* {.final.}: BN

#Construcor.
func newIndex*(address: string, nonce: BN): Index {.raises: [].} =
    result = Index(
        address: address,
        nonce: nonce
    )
