#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Difficulties object.
import DifficultiesObj

#Transaction object.
import TransactionObj

#Tables standard library.
import tables

type
    Difficulties* = object
        send*: Hash[384]
        data*: Hash[384]

    Transactions = ref object
        db*: DatabaseFunctionBox

        difficulties: Difficulties

        transactions: Table[
            string,
            Transaction
        ]

        verifications*: Table[
            string,
            seq[BLSPublicKey]
        ]

        weights*: Table[
            string,
            int
        ]
