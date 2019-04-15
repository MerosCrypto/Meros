include MainLattice

proc mainPersonal() {.forceCheck: [].} =
    {.gcsafe.}:
        #Get the Wallet.
        functions.personal.getWallet = proc (): Wallet {.forceCheck: [].} =
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
                    raise e
                except SodiumError as e:
                    raise e
            else:
                try:
                    wallet = newWallet(newEdSeed(seed))
                except EdSeedError as e:
                    raise e
                except SodiumError as e:
                    raise e

        #Sign a Send.
        functions.personal.signSend = proc (
            send: Send
        ) {.forceCheck: [
            ValueError,
            AddressError,
            SodiumError
        ].} =
            try:
                wallet.sign(send)
            except ValueError as e:
                raise e
            except AddressError as e:
                raise e
            except SodiumError as e:
                raise e

        #Sign a Receive.
        functions.personal.signReceive = proc (
            recv: Receive
        ) {.forceCheck: [
            SodiumError
        ].} =
            try:
                wallet.sign(recv)
            except SodiumError as e:
                raise e

        functions.personal.signData = proc (data: Data) {.forceCheck: [
            AddressError,
            SodiumError
        ].} =
            try:
                wallet.sign(data)
            except AddressError as e:
                raise e
            except SodiumError as e:
                raise e
