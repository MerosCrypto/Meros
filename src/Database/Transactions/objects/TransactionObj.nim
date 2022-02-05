import hashes

import ../../../lib/[Errors, Hash]
import ../../../Wallet/Wallet

type
  Input* = ref object of RootObj
    hash*: Hash.Hash[256]

  #FundedInput, which includes a nonce specifying the output to use the funds of.
  FundedInput* = ref object of Input
    nonce*: int

  Output* = ref object of RootObj
    amount*: uint64

  #MintOutput, which sends to a MeritHolder nickname.
  MintOutput* = ref object of Output
    key*: uint16

  #SendOutput, which sends to an RistrettoPublicKey. This is also used by Claim.
  SendOutput* = ref object of Output
    key*: RistrettoPublicKey

  Transaction* = ref object of RootObj
    inputs*: seq[Input]
    outputs*: seq[Output]
    hash*: Hash.Hash[256]

proc `==`*(
  lhs: Input,
  rhs: Input
): bool {.forceCheck: [].} =
  result = lhs.hash == rhs.hash
  if lhs of FundedInput:
    result = result and
      (rhs of FundedInput) and
      (cast[FundedInput](lhs).nonce == cast[FundedInput](rhs).nonce)

proc hash*(
  input: Input
): hashes.Hash {.inline, forceCheck: [].} =
  var nonce: int = 0
  if input of FundedInput:
    nonce = cast[FundedInput](input).nonce
  !$ (hash(input.hash) !& nonce)

func newInput*(
  hash: Hash.Hash[256]
): Input {.inline, forceCheck: [].} =
  Input(
    hash: hash
  )

func newFundedInput*(
  hash: Hash.Hash[256],
  nonce: int
): FundedInput {.inline, forceCheck: [].} =
  FundedInput(
    hash: hash,
    nonce: nonce
  )

func newOutput*(
  amount: uint64
): Output {.inline, forceCheck: [].} =
  Output(
    amount: amount
  )

func newMintOutput*(
  key: uint16,
  amount: uint64
): MintOutput {.inline, forceCheck: [].} =
  MintOutput(
    key: key,
    amount: amount
  )

func newClaimOutput*(
  key: RistrettoPublicKey
): SendOutput {.inline, forceCheck: [].} =
  SendOutput(
    key: key
  )

func newSendOutput*(
  key: RistrettoPublicKey,
  amount: uint64
): SendOutput {.inline, forceCheck: [].} =
  SendOutput(
    key: key,
    amount: amount
  )

proc newSendOutput*(
  addy: Address,
  amount: uint64
): SendOutput {.forceCheck: [].} =
  case addy.addyType:
    of AddressType.None: panic("AddressType None entered the system.")
    of AddressType.PublicKey:
      result = newSendOutput(newRistrettoPublicKey(cast[string](addy.data)), amount)
