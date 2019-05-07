#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Entry and Mint objects.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/MintObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Mint.
proc serialize*(
    mint: Mint,
    hashing: bool
): string {.forceCheck: [].} =
    result =
        mint.nonce.toBinary().pad(INT_LEN) &
        mint.output.toString() &
        mint.amount.toBinary().pad(MEROS_LEN)

    if hashing:
        result = "mint" & result
