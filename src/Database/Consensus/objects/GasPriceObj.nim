#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element object.
import ElementObj
export ElementObj

#Finals lib.
import finals

#GasPrice objects.
finalsd:
    type
        GasPrice* = ref object of Element
            price* {.final.}: uint32

        SignedGasPrice* = ref object of GasPrice
            signature* {.final.}: BLSSignature

#Constructors.
func newGasPriceObj*(
    price: uint32
): GasPrice {.forceCheck: [].} =
    result = GasPrice(
        price: price
    )
    result.ffinalizePrice()

func newSignedGasPriceObj*(
    price: uint32
): SignedGasPrice {.forceCheck: [].} =
    result = SignedGasPrice(
        price: price
    )
    result.ffinalizePrice()
