include MainLattice

proc mainPersonal() {.forceCheck: [].} =
    {.gcsafe.}:
        #Get the Wallet.
        functions.personal.getWallet = proc (): Wallet {.inline, forceCheck: [].} =
            wallet

        #Set the Wallet's seed.
        functions.personal.setSeed = proc (
            seed: string
        ) {.forceCheck: [
            RandomError,
            EdSeedError,
            SodiumError
        ].} =
            if seed.len == 0:
                try:
                    wallet = newWallet()
                except RandomError as e:
                    fcRaise e
                except SodiumError as e:
                    fcRaise e
            else:
                try:
                    wallet = newWallet(newEdSeed(seed))
                except EdSeedError as e:
                    fcRaise e
                except SodiumError as e:
                    fcRaise e

        #Sign a Send.
        functions.personal.signSend = proc (
            send: Send
        ) {.forceCheck: [
            AddressError,
            SodiumError
        ].} =
            try:
                wallet.sign(send)
            except AddressError as e:
                fcRaise e
            except SodiumError as e:
                fcRaise e

        #Sign a Receive.
        functions.personal.signReceive = proc (
            recv: Receive
        ) {.forceCheck: [
            SodiumError
        ].} =
            try:
                wallet.sign(recv)
            except SodiumError as e:
                fcRaise e

        functions.personal.signData = proc (data: Data) {.forceCheck: [
            AddressError,
            SodiumError
        ].} =
            try:
                wallet.sign(data)
            except AddressError as e:
                fcRaise e
            except SodiumError as e:
                fcRaise e
