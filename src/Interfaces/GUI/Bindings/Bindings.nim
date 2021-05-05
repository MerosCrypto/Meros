import ../../../lib/Errors

import ../objects/GUIObj
import GUIBindings

#Meant to be expanded with dedicated RPC functions for each RPC route.
#Currently just binds GUI_quit, GUI_poll, and RPC_call via the GUIBindings file.
proc createBindings*(
  gui: var GUI,
  poll: CarriedCallback
) {.forceCheck: [].} =
  GUIBindings.addTo(gui, poll)
