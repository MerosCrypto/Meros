#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet libs.
import ../../../Wallet/Wallet
import ../../../Wallet/MinerWallet

#Finals lib.
import finals

finalsd:
    type
        #Transaction input types.
        Input* = ref object of RootObj
            hash* {.final.}: Hash[384]
        #SendInput, which also includes a nonce.
        SendInput* = ref object of Input
            nonce* {.final,}: int

        #Transaction output types.
        Output* = ref object of RootObj
            amount* {.final.}: uint64
        #MintOutput, which sends to a BLSPublicKey.
        MintOutput* = ref object of Output
            key* {.final.}: BLSPublicKey
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
            #Verified.
            verified*: bool

#Input/Output constructors.
func newInput*(
    hash: Hash[384]
): Input {.inline, forceCheck: [].} =
    result = Input(
        hash: hash
    )
    result.ffinalizeHash()

func newSendInput*(
    hash: Hash[384],
    nonce: int
): SendInput {.inline, forceCheck: [].} =
    result = SendInput(
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
    key: BLSPublicKey,
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
