include MainGlobals

#Create the Lattice.
lattice = newLattice()
#Create the Genesis Send.
genesisSend = lattice.mint(
    "Emb0h3nyv8uplrx68677ca6t0t4x6qhsue90y50ntwq3dfj5hxw246s",
    newBN("1000000")
)

#Handle Sends.
events.on(
    "lattice.send",
    proc (send: Send): bool {.raises: [Exception].} =
        #Print that we're adding the node.
        echo "Adding a new Send."

        #Add the Send.
        if lattice.add(
            send
        ):
            echo "Successfully added the Send."
            result = true
        else:
            echo "Failed to add the Send."
            result = false
        echo ""
)

#Handle Receives.
events.on(
    "lattice.receive",
    proc (recv: Receive): bool {.raises: [Exception].} =
        #Print that we're adding the node.
        echo "Adding a new Receive."

        #Add the Receive.
        if lattice.add(
            recv
        ):
            echo "Successfully added the Receive."
            result = true
        else:
            echo "Failed to add the Receive."
            result = false
        echo ""
)

#Handle Data.
events.on(
    "lattice.data",
    proc (msg: Message, data: Data): bool {.raises: [Exception].} =
        #Print that we're adding the node.
        echo "Adding a new Data."

        #Add the Data.
        if lattice.add(
            data
        ):
            echo "Successfully added the Data."
            result = true
        else:
            echo "Failed to add the Data."
            result = false
        echo ""
)

#Handle Verifications.
events.on(
    "lattice.verification",
    proc (verif: Verification): bool {.raises: [Exception].} =
        #Print that we're adding the node.
        echo "Adding a new Verification."

        #Add the Verification.
        if lattice.add(
            verif
        ):
            echo "Successfully added the Verification."
            result = true
        else:
            echo "Failed to add the Verification."
            result = false
        echo ""
)

#Handle requests for an account's height.
events.on(
    "lattice.getHeight",
    proc (account: string): BN {.raises: [ValueError].} =
        lattice.getHeight(account)
)

#Handle requests for an account's balance.
events.on(
    "lattice.getBalance",
    proc (account: string): BN {.raises: [ValueError].} =
        lattice.getBalance(account)
)

#Print the Private Key and address of the address holding the coins.
echo "Emb0h3nyv8uplrx68677ca6t0t4x6qhsue90y50ntwq3dfj5hxw246s" &
    " was sent one million coins from \"minter\". Its Private Key is " &
    "7A3E64ADDB86DA2F3D1BEF18F6D2C80BA5C5EF9673DE8A0F5787DF8E6DD237427DE33230FC0FC66D1F5EF63BA5BD7536817873257928F9ADC08B532A5CCE5575" &
    ".\r\n"
