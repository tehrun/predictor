import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: document.querySelector("meta[name='csrf-token']")?.content}})
liveSocket.connect()
window.liveSocket = liveSocket
