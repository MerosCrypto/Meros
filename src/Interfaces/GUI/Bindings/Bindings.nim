import ../../../lib/Errors

import ../objects/GUIObj
import GUIBindings, PersonalBindings, NetworkBindings

proc createBindings*(
  gui: GUI,
  loop: proc () {.raises: [
    WebViewError
  ].}
) {.forceCheck: [].} =
  try:
    GUIBindings.addTo(gui, loop)
  except WebViewError as e:
    panic("GUIBindings.addTo threw a WebViewError just by passing it loop, despite having a blank raises pragma: " & e.msg)
  PersonalBindings.addTo(gui)
  NetworkBindings.addTo(gui)
