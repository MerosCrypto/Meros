include MainDatabase

proc mainPersonal() {.raises: [].} =
    {.gcsafe.}:
        #Get the Wallet.
        functions.personal.getWallet = proc (): Wallet {.raises: [].} =
            wallet

        #Set the Wallet's seed.
        functions.personal.setSeed = proc (seed: string) {.raises: [
            ValueError,
            RandomError,
            SodiumError
        ].} =
            if seed.len == 0:
                wallet = newWallet()
            else:
                wallet = newWallet(newEdSeed(seed))

        #Sign a Send.
        functions.personal.signSend = proc (send: Send) {.raises: [
            ValueError,
            SodiumError,
            FinalAttributeError
        ].} =
            wallet.sign(send)

        #Sign a Receive.
        functions.personal.signReceive = proc (recv: Receive) {.raises: [SodiumError, FinalAttributeError].} =
            wallet.sign(recv)

        functions.personal.signData = proc (data: Data) {.raises: [
            ValueError,
            SodiumError,
            FinalAttributeError
        ].} =
            wallet.sign(data)
