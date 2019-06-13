import ../../../lib/Errors

import ../../../lib/Hash

import ../../../Wallet/MinerWallet

import ../SerializeCommon

import ../../../Database/Consensus/objects/DataDifficultyObj

method serialize*(
    dd: DataDifficulty,
    signingOrVerifying: bool = false
): string {.forceCheck: [].} =
    result =
        dd.holder.toString() &
        dd.nonce.toBinary().pad(INT_LEN) &
        dd.difficulty.toString()

    if signingOrVerifying:
        result = "dataDifficulty" & result
