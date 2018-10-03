include MainImports

#---------- Lattice ----------
var
    minter: Wallet = newWallet(
        newPrivateKey(
            "35383933433943323039424539304442394237324441314633334641413138384341443133313238303836354234383134313331433935384633373332423132"
        )
    )                                #Wallet.
    lattice: Lattice = newLattice()  #Lattice.
    mintIndex: Index = lattice.mint( #Gensis Send.
        minter.address,
        newBN("1000000")
    )

#Print the Private Key and address of the address holding the coins.
echo minter.address &
    " was sent one million coins from \"minter\". Its Private Key is " &
    $minter.privateKey &
    ".\r\n"
