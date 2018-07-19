import nimx/window as WindowFile
import nimx/text_field

var
    window = newWindow(newRect(40, 40, 800, 600))
    label = newLabel(newRect(20, 20, 150, 20))

label.text = "Hello, world!"
window.addSubview(label)

runApplication:
    discard
