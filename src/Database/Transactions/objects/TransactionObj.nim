#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Finals lib.
import finals

finalsd:
    type
        #Transaction input types.
        Input* = ref object of RootObj
            hash* {.final.}: Hash[384]
        #FundedInput, which also includes a nonce.
        FundedInput* = ref object of Input
            nonce* {.final,}: int

        #Transaction output types.
        Output* = ref object of RootObj
            amount* {.final.}: uint64
        #MintOutput, which sends to a MeritHolder nickname.
        MintOutput* = ref object of Output
            key* {.final.}: uint16
        #SendOutput, which sends to an EdPublicKey. This also used by Claim.
        SendOutput* = ref object of Output
            key* {.final.}: EdPublicKey

        #Transaction object.
        Transaction* = ref object of RootObj
            #Input transactions.
            inputs*: seq[Input]
            #Outputs,
            outputs*: seq[Output]
            #Hash.
            hash* {.final.}: Hash[384]

#Input/Output constructors.
func newInput*(
    hash: Hash[384]
): Input {.inline, forceCheck: [].} =
    result = Input(
        hash: hash
    )
    result.ffinalizeHash()

func newFundedInput*(
    hash: Hash[384],
    nonce: int
): FundedInput {.inline, forceCheck: [].} =
    result = FundedInput(
        hash: hash,
        nonce: nonce
    )
    result.ffinalizeHash()
    result.ffinalizeNonce()

func newOutput*(
    amount: uint64
): Output {.inline, forceCheck: [].} =
    result = Output(
        amount: amount
    )
    result.ffinalizeAmount()

func newMintOutput*(
    key: uint16,
    amount: uint64
): MintOutput {.inline, forceCheck: [].} =
    result = MintOutput(
        key: key,
        amount: amount
    )
    result.ffinalizeKey()
    result.ffinalizeAmount()

func newClaimOutput*(
    key: EdPublicKey
): SendOutput {.inline, forceCheck: [].} =
    result = SendOutput(
        key: key
    )
    result.ffinalizeKey()

func newSendOutput*(
    key: EdPublicKey,
    amount: uint64
): SendOutput {.inline, forceCheck: [].} =
    result = SendOutput(
        key: key,
        amount: amount
    )
    result.ffinalizeKey()
    result.ffinalizeAmount()
