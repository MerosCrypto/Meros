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
            hash {.final.}: Hash[384]
        #SendInput, which also includes a nonce.
        SendInput* = ref object of Input
            nonce {.final,}: uint8

        #Transaction output types.
        Output* = ref object
            amount: uint64
        #MintOutput, which sends to a BLSPublicKey.
        MintOutput* = ref object of Output
            key: BLSPublicKey
        #SendOutput, which sends to an EdPublicKey. This also used by Claim.
        SendOutput* = ref object of Output
            key: EdPublicKey

        #Enum of the various Transaction Types.
        TransactionType* = enum
            Mint = 0,
            Claim = 1,
            Send = 2,
            Data = 3

        #Transaction object.
        Transaction* = ref object of RootObj
            #Type of descendant.
            descendant* {.final.}: TransactionType
            #Input transactions.
            inputs*: seq[Input]
            #Outputs,
            outputs*: seq[Output]
            #Hashed or not.
            hashed* {.final.}: bool
            #Hash.
            hash* {.final.}: Hash[384]
            #Signature.
            signature* {.final.}: EdSignature
            #Verified.
            verified*: bool
