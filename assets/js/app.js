// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/tap_game"
import topbar from "../vendor/topbar"

// Custom Hooks
let Hooks = {}

Hooks.TapHandler = {
  mounted() {
    this.tapCount = 0
    this.lastSent = 0
    this.syncInterval = null
    this.isPlaying = false

    const sendUpdate = () => {
      if (this.isPlaying && this.tapCount > this.lastSent) {
        this.pushEvent("tap_update", { count: this.tapCount })
        this.lastSent = this.tapCount
      }
    }

    // Handle button clicks
    this.el.addEventListener("click", (e) => {
      if (this.isPlaying) {
        e.preventDefault()
        this.tapCount++
        this.updateDisplay()
        sendUpdate()
      }
    })

    // Handle spacebar
    this.handleKeyDown = (e) => {
      if (this.isPlaying && (e.code === "Space" || e.key === " ")) {
        e.preventDefault()
        this.tapCount++
        this.updateDisplay()
        sendUpdate()
      }
    }
    window.addEventListener("keydown", this.handleKeyDown)

    // Periodic sync every 200ms for smooth updates
    this.syncInterval = setInterval(sendUpdate, 200)

    // Listen for game state changes
    this.handleEvent("game_state_changed", ({ status }) => {
      this.isPlaying = (status === "playing")
      if (status === "playing") {
        this.tapCount = 0
        this.lastSent = 0
      }
    })
  },

  updateDisplay() {
    // Update the tap count display element
    const countEl = document.getElementById("tap-count-display")
    if (countEl) {
      countEl.textContent = this.tapCount
    }
  },

  destroyed() {
    if (this.syncInterval) {
      clearInterval(this.syncInterval)
    }
    if (this.handleKeyDown) {
      window.removeEventListener("keydown", this.handleKeyDown)
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

