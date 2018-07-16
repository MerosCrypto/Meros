#BN lib.
import BN

#Block object.
type Block* = ref object of RootObj
    #Input address. This address for a send block, a different one for a receive block.
    input*: string
    #Output address. This address for a receive block,  different one for a send block.
    output*: string
    #Amount transacted.
    amount*: BN
    #Data included in the TX.
    data*: string
    #Work to provee this isn't spam.
    work*: BN
    #Block hash.
    hash: string
    #Block signature.
    signature: string
