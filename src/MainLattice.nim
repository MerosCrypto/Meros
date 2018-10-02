include MainImports

#---------- Lattice ----------
var
    minter: Wallet = newWallet(
        "5893C9C209BE90DB9B72DA1F33FAA188CAD131280865B4814131C958F3732B12"
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
