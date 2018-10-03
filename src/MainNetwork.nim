include MainLattice

#---------- Network ----------
var
    events: EventEmitter = newEventEmitter() #EventEmitter for the Network.
    network: Network = newNetwork(0, events) #Network object.

#Handle Sends.
events.on(
    "send",
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
    "recv",
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
    "data",
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
    "verif",
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

#Start listening.
network.start(5132)
