#Util lib.
import ../../lib/Util

#Base lib.
import ../../lib/Base

#Address lib.
import ../../Wallet/Address

#Entry and Mint object.
import ../../Database/Lattice/objects/EntryObj
import ../../Database/Lattice/objects/MintObj

#Common serialization functions.
import SerializeCommon

#Serialize a Mint.
proc serialize*(mint: Mint): string {.raises: [].} =
    result =
        !mint.nonce.toBinary() &
        !mint.output &
        !mint.amount.toString(256)
