import nimx/window as WindowFile
import nimx/text_field

var
    window: Window = newWindow(newRect(40, 40, 800, 600))
    label: TextField = newLabel(newRect(20, 20, 150, 20))

label.text = "Ember UI"
window.addSubview(label)

runApplication:
    discard
