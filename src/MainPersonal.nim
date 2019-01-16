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

        #Sign a Data.
        #The junk uint is needed. If this is Data alone, it will not compile.
        #I do not know why. We have other events which are just Data.
        #Data is almost identical to Send. Send works fine.
        #That said, this will fail without it. Don't remove it.
        #--Kayaba
        events.on(
            "personal.signData",
            proc (data: Data, junk: uint = 0): bool {.raises: [ValueError, SodiumError, FinalAttributeError].} =
                wallet.sign(data)
            )
