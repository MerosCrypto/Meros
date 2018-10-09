include MainMerit

#Create the Lattice.
lattice = newLattice(
    TRANSACTION_DIFFICULTY,
    DATA_DIFFICULTY
)

#Create the Genesis Send.
genesisSend = lattice.mint(
    MINT_ADDRESS,
    newBN(MINT_AMOUNT)
)

#Handle Sends.
events.on(
    "lattice.send",
    proc (send: Send): bool {.raises: [ValueError, SodiumError].} =
        #Print that we're adding the node.
        echo "Adding a new Send."

        #Add the Send.
        if lattice.add(
            merit,
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
    proc (recv: Receive): bool {.raises: [ValueError, SodiumError].} =
        #Print that we're adding the node.
        echo "Adding a new Receive."

        #Add the Receive.
        if lattice.add(
            merit,
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
    proc (msg: Message, data: Data): bool {.raises: [ValueError, SodiumError].} =
        #Print that we're adding the node.
        echo "Adding a new Data."

        #Add the Data.
        if lattice.add(
            merit,
            data
        ):
            echo "Successfully added the Data."
            result = true
        else:
            echo "Failed to add the Data."
            result = false
        echo ""
)

#Handle requests for an account's height.
events.on(
    "lattice.getHeight",
    proc (account: string): BN {.raises: [ValueError].} =
        lattice.getAccount(account).height
)

#Handle requests for an account's balance.
events.on(
    "lattice.getBalance",
    proc (account: string): BN {.raises: [ValueError].} =
        lattice.getAccount(account).balance
)

#Print the Private Key and address of the address holding the coins.
echo MINT_ADDRESS & " was sent " & MINT_AMOUNT & " coins from \"minter\".\r\n" &
    "Its Private Key is " & MINT_KEY & ".\r\n"
