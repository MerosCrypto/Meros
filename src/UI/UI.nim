#Errors lib.
import ../lib/Errors

#SDL lib.
import sdl2/sdl

#UI object.
type UI = ref object of RootObj
    window: Window
    renderer: Renderer

proc newUI*(): UI {.raises: [ResultError].} =
    #Init SDL.
    if sdl.init(InitVideo) != 0:
        raise newException(ResultError, "Couldn't init SDL.")

    #Create the UI/the window.
    result = UI(
        window: createWindow(
            "Ember Cryptocurrency",
            WindowPosUndefined,
            WindowPosUndefined,
            500,
            500,
            0
        )
    )
    #Verify the Window's integrity.
    if result.window.isNil:
        raise newException(ResultError, "Couldn't create the Window.")

    #Create the Renderer.
    result.renderer = createRenderer(
        result.window,
        -1,
        RendererAccelerated or RendererPresentVsync
    )
    #Verify the Renderer's integrity.
    if result.renderer.isNil:
        raise newException(ResultError, "Couldn't create the Renderer.")

    #Set the draw color.
    if result.renderer.setRenderDrawColor(0xFF, 0xFF, 0xFF, 0xFF) != 0:
        raise newException(ResultError, "Couldn't set the draw color.")

    #Clear the renderer.
    if result.renderer.renderClear() != 0:
        raise newException(ResultError, "Could not clear the Renderer.")

    #Render.
    result.renderer.renderPresent()

#Destroy function.
proc destroy*(ui: UI) {.raises: [].} =
    ui.renderer.destroyRenderer()
    ui.window.destroyWindow()
    sdl.quit()
