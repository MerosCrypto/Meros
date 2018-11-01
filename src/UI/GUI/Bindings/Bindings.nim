#Errors lib.
import ../../../lib/Errors

#GUI object.
import ../objects/GUIObj

#Each of the scopes.
import GUIBindings
import PersonalBindings
import LatticeBindings
import NetworkBindings

#Create the bindings.
proc createBindings*(gui: GUI, loop: proc ()) {.raises: [WebViewError].} =
    #Add the GUI bindings.
    GUIBindings.addTo(gui, loop)
    #Add the Wallet bindings.
    PersonalBindings.addTo(gui)
    #Add the Lattice bindings.
    LatticeBindings.addTo(gui)
    #Add the Network bindings.
    NetworkBindings.addTo(gui)
