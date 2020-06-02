#Errors lib.
import ../../../lib/Errors

#Wallet libs.
import ../../../Wallet/Wallet
import ../../../Wallet/MinerWallet

#Transaction object.
import TransactionObj
export TransactionObj

#Mint object.
import MintObj

#Claim object.
type Claim* = ref object of Transaction
  #BLS Signature that proves the Merit Holder which earned these Mints wants the specified output to receive their reward.
  signature*: BLSSignature

#Claim constructor.
func newClaimObj*(
  inputs: varargs[FundedInput],
  output: EdPublicKey
): Claim {.inline, forceCheck: [].} =
  Claim(
    inputs: cast[seq[Input]](@inputs),
    outputs: cast[seq[Output]](@[
      newClaimOutput(output)
    ])
  )
