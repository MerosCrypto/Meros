include MainLattice

proc mainPersonal() {.raises: [ValueError, RandomError, SodiumError, FinalAttributeError].} =
    {.gcsafe.}:
        #Get the Wallet.
        events.on(
            "personal.getWallet",
            proc (): Wallet {.raises: [].} =
                wallet
        )

        #Set the Wallet's seed.
        events.on(
            "personal.setSeed",
            proc (seed: string) {.raises: [ValueError, RandomError, SodiumError].} =
                if seed.len == 0:
                    wallet = newWallet()
                else:
                    wallet = newWallet(newEdSeed(seed))
        )

        #Sign a Send.
        events.on(
            "personal.signSend",
            proc (send: Send): bool {.raises: [ValueError, SodiumError, FinalAttributeError].} =
                wallet.sign(send)
        )

        #Sign a Receive.
        events.on(
            "personal.signReceive",
            proc (recv: Receive) {.raises: [SodiumError, FinalAttributeError].} =
                wallet.sign(recv)
        )
