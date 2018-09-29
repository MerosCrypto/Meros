#UI object.
import ../objects/UIObj

#Each of the scopes.
import UIBindings
import WalletBindings
import LatticeBindings

#Create the bindings.
proc createBindings*(ui: UI) {.raises: [Exception].} =
    #Add the UI bindings.
    UIBindings.addTo(ui)
    #Add the Wallet bindings.
    WalletBindings.addTo(ui)
    #Add the Lattice bindings.
    LatticeBindings.addTo(ui)
