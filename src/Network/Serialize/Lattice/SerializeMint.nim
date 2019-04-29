#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BN/Raw lib.
import ../../../lib/Raw

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Entry and Mint objects.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/MintObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Mint.
proc serialize*(
    mint: Mint
): string {.forceCheck: [].} =
    result =
        mint.nonce.toBinary().pad(INT_LEN) &
        mint.output.toString() &
        mint.amount.toRaw().pad(MEROS_LEN)
