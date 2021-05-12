import ../../../lib/Errors
import ../../../Wallet/[Wallet, MinerWallet]

import TransactionObj
export TransactionObj

type Claim* = ref object of Transaction
  #BLS Signature that proves the Merit Holder which earned the Mint wants the specified output to receive their reward.
  signature*: BLSSignature

func newClaimObj*(
  inputs: varargs[FundedInput],
  output: RistrettoPublicKey
): Claim {.inline, forceCheck: [].} =
  Claim(
    inputs: cast[seq[Input]](@inputs),
    outputs: cast[seq[Output]](@[
      newClaimOutput(output)
    ])
  )
