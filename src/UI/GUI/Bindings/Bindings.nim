#Errors lib.
import ../../../lib/Errors

#GUI object.
import ../objects/GUIObj

#Each of the scopes.
import GUIBindings
import PersonalBindings
import TransactionsBindings
import NetworkBindings

#Create the bindings.
proc createBindings*(
    gui: GUI,
    loop: proc () {.raises: [
        WebViewError
    ].}
) {.forceCheck: [].} =
    #Add the GUI bindings.
    try:
        GUIBindings.addTo(gui, loop)
    except WebViewError as e:
        doAssert(false, "GUIBindings.addTo threw a WebViewError just by passing it loop, despite having a blank raises pragma: " & e.msg)
    #Add the Wallet bindings.
    PersonalBindings.addTo(gui)
    #Add the Transactions bindings.
    TransactionsBindings.addTo(gui)
    #Add the Network bindings.
    NetworkBindings.addTo(gui)
