import ../lib/[Errors, Hash]

import Mnemonic, HDWallet
export Mnemonic, HDWallet

type InsecureWallet* = ref object
  mnemonic*: Mnemonic
  password*: string
  hd*: HDWallet

#Create a new Wallet.
proc newWallet*(
  password: string
): InsecureWallet {.forceCheck: [].} =
  while true:
    try:
      result = InsecureWallet(
        mnemonic: newMnemonic(),
        password: password
      )
      result.hd = newHDWallet(SHA2_256(result.mnemonic.unlock(password)).serialize())

      #Guarantee account 0 is usable.
      #This getter automatically checks the internal/external chains as well.
      discard result.hd[0]

      break
    except ValueError:
      continue

#Load an existing Wallet.
proc newWallet*(
  mnemonicArg: string,
  password: string
): InsecureWallet {.forceCheck: [
  ValueError
].} =
  try:
    let mnemonic: Mnemonic = newMnemonic(mnemonicArg)
    result = InsecureWallet(
      mnemonic: mnemonic,
      password: password,
      hd: newHDWallet(SHA2_256(mnemonic.unlock(password)).serialize())
    )
    discard result.hd[0]
  except ValueError as e:
    raise e
