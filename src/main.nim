#BN lib.
import BN

#Wallet lib.
import Wallet/Wallet

#Lattice lib.
import Database/Lattice/Lattice

#Network lib.
import Network/Network

#Async standard lib.
import asyncdispatch

var
    minter: Wallet = newWallet()     #Wallet.
    lattice: Lattice = newLattice()  #Lattice.
    mintIndex: Index = lattice.mint( #Mint transaction.
        minter.getAddress(),
        newBN("1000000")
    )
    mintRecv: Receive = newReceive(  #Mint Receive.
        mintIndex,
        newBN()
    )
    network: Network = newNetwork(0) #Netowk object.

#Sign and add the Mint Receive.
discard minter.sign(mintRecv)
discard lattice.add(mintRecv)

#Print the Private Key and address of the address holding the coins.
echo minter.getAddress() &
    " was minted, and has received, one million coins. Its Private Key is " &
    $minter.getPrivateKey() &
    "."

runForever()
