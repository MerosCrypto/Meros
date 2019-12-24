#This is named NetworkLibFunctionBox, not NetworkFunctionBox, `because GlobalFunctionBox` also defines a `NetworkFunctionBox`.

#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Block lib.
import ../../Database/Merit/Block

#Transaction lib.
import ../../Database/Transactions/Transaction

#Message object.
import MessageObj

#Async standard lib.
import asyncdispatch

type NetworkLibFunctionBox* = ref object
    getNetworkID*: proc (): int {.noSideEffect, raises: [].}
    getProtocol*: proc (): int {.noSideEffect, raises: [].}

    getTail*: proc (): Hash[384] {.inline, gcsafe, raises: [].}

    getBlockHashBefore*: proc (
        hash: Hash[384]
    ): Hash[384] {.raises: [
        IndexError
    ], gcsafe.}

    getBlockHashAfter*: proc (
        hash: Hash[384]
    ): Hash[384] {.raises: [
        IndexError
    ], gcsafe.}

    getBlock*: proc (
        hash: Hash[384]
    ): Block {.raises: [
        IndexError
    ], gcsafe.}

    getTransaction*: proc (
        hash: Hash[384]
    ): Transaction {.raises: [
        IndexError
    ], gcsafe.}

    handle*: proc (
        msg: Message
    ): Future[void] {.gcsafe.}

func newNetworkLibFunctionBox*(): NetworkLibFunctionBox {.forceCheck: [].} =
    NetworkLibFunctionBox()
