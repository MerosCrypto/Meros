#BN lib.
import BN

#Wallet.
import Wallet/Wallet

#Lattice.
import Database/Lattice/Lattice

#Network.
import Network/Network

#UI.
import UI/UI

#Event lib.
import ec_events

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#---------- Lattice ----------
var
    minter: Wallet = newWallet(
        "5893C9C209BE90DB9B72DA1F33FAA188CAD131280865B4814131C958F3732B12"
    )                                #Wallet.
    lattice: Lattice = newLattice()  #Lattice.
    mintIndex: Index = lattice.mint( #Mint transaction.
        minter.address,
        newBN("1000000")
    )
    mintRecv: Receive = newReceive(  #Mint Receive.
        mintIndex,
        newBN()
    )
#Sign and add the Mint Receive.
minter.sign(mintRecv)
discard lattice.add(mintRecv)

#Print the Private Key and address of the address holding the coins.
echo minter.address &
    " was minted, and has received, one million coins. Its Private Key is " &
    $minter.privateKey & ".\r\n"

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

#------------ UI ------------

#Handle the WebView closing.
events.on(
    "quit",
    proc () {.raises: [Exception].} =
        #Shut down the Network.
        network.shutdown()
        #Quit.
        quit(0)
)

#Create the GUI.
#var gui: GUI = newGUI(events, 1000, 500)
#gui.run()

#Run forever.
runForever()
