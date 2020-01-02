#Errors lib.
import ../../../../lib/Errors

#MinerWallet lib.
import ../../../../Wallet/MinerWallet

#Element object.
import ElementObj
export ElementObj

#GasPrice objects.
type
    GasPrice* = ref object of BlockElement
        price*: uint32

    SignedGasPrice* = ref object of GasPrice
        signature*: BLSSignature

#Constructors.
func newGasPriceObj*(
    price: uint32
): GasPrice {.inline, forceCheck: [].} =
    GasPrice(
        price: price
    )

func newSignedGasPriceObj*(
    price: uint32
): SignedGasPrice {.inline, forceCheck: [].} =
    SignedGasPrice(
        price: price
    )
