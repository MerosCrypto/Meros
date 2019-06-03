include MainLattice

proc mainPersonal() {.forceCheck: [].} =
    {.gcsafe.}:
        #Get the Wallet.
        functions.personal.getWallet = proc (): Wallet {.inline, forceCheck: [].} =
            wallet

        #Set the Wallet's secret.
        functions.personal.setSecret = proc (
            secret: string
        ) {.forceCheck: [
            ValueError,
            RandomError
        ].} =
            if secret.len == 0:
                try:
                    wallet = newHDWallet()
                except ValueError as e:
                    fcRaise e
                except RandomError as e:
                    fcRaise e
            else:
                try:
                    wallet = newHDWallet(secret)
                except ValueError as e:
                    fcRaise e

        #Sign a Send.
        functions.personal.signSend = proc (
            send: Send
        ) {.forceCheck: [
            AddressError
        ].} =
            try:
                wallet.sign(send)
            except AddressError as e:
                fcRaise e

        #Sign a Receive.
        functions.personal.signReceive = proc (
            recv: Receive
        ) {.forceCheck: [].} =
            wallet.sign(recv)

        functions.personal.signData = proc (data: Data) {.forceCheck: [
            AddressError
        ].} =
            try:
                wallet.sign(data)
            except AddressError as e:
                fcRaise e
