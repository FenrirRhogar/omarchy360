import QtQuick
import Quickshell.Io

// Client for the douze daemon, which owns the SSL 12's USB control interface:
// GET /state, POST /api, and the /events stream (meters ~15/s, state echoes,
// front-panel button presses). Only talks to it while active.
Item {
  id: root

  property bool active: false
  property string base: "http://127.0.0.1:1212"

  property var st: null        // daemon state (channels, sends, masters, …)
  property var meters: []      // raw meter words, see Ssl.js for indices
  property bool online: false  // daemon reachable
  property string error: ""
  readonly property bool device: online && !!st && st._device !== false
  readonly property int clock: st && st._clock && st._clock.length ? st._clock[0] : 0

  // Extensions this douze offers beyond its base API (see README): a stock
  // daemon announces none, and the views hide what it can't do.
  readonly property var features: st && st._features ? st._features : []
  function has(feature) { return features.indexOf(feature) !== -1 }

  function request(method, path, body, done) {
    var xhr = new XMLHttpRequest()
    xhr.timeout = 4000
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (xhr.status === 0) {
        root.online = false
        done(null)
        return
      }
      root.online = true
      var r = null
      try {
        r = JSON.parse(xhr.responseText)
      } catch (e) {
        root.error = "bad reply from douze"
      }
      done(r)
    }
    xhr.open(method, root.base + path)
    if (body !== undefined) xhr.setRequestHeader("Content-Type", "application/json")
    xhr.send(body === undefined ? null : JSON.stringify(body))
  }

  function refresh() {
    request("GET", "/state", undefined, s => { if (s) root.st = s })
  }

  // Commands go out one at a time, in order: each reply carries the whole
  // state, so overlapping requests could land out of order and briefly show
  // an older state than the card has.
  property var queue: []
  property bool busy: false

  function api(cmd) {
    queue.push(cmd)
    if (!busy) next()
  }

  function next() {
    var cmd = queue.shift()
    if (!cmd) {
      busy = false
      return
    }
    busy = true
    request("POST", "/api", cmd, r => {
      if (r && r.ok) {
        root.st = r.state
        root.error = ""
      } else if (r) {
        root.error = (r.error || "error") + " (" + cmd.cmd + ")"
      }
      root.next()
    })
  }

  // Continuous controls (faders, pan, levels) send at most every 50 ms; the
  // latest value per control wins.
  property var pending: ({})
  function send(key, cmd) {
    pending[key] = cmd
    if (!flushTimer.running) flushTimer.start()
  }

  Timer {
    id: flushTimer
    interval: 50
    onTriggered: {
      // Hold drags back while a command is in flight, so only the latest
      // value per control queues up behind it.
      if (root.busy) {
        restart()
        return
      }
      var p = root.pending
      root.pending = {}
      for (var k in p) root.api(p[k])
    }
  }

  // SplitParser hands back the line after SSE's blank separator with the
  // newline still in front; trim it before matching "data: ".
  function onEvent(line) {
    line = line.trim()
    if (line.indexOf("data: ") !== 0) return
    var m
    try { m = JSON.parse(line.slice(6)) } catch (e) { return }
    root.online = true
    if (m.ev === "meters") root.meters = m.v
    else if (m.ev === "state") root.st = m.state
    else if (m.ev === "bool") root.refresh()   // front panel or another client
    else if (m.ev === "clock" && root.st) {
      var s = Object.assign({}, root.st)
      s._clock = m.rates
      s._clock_mismatch = m.mismatch
      root.st = s
    }
  }

  Process {
    id: events
    command: ["curl", "-sN", "--no-buffer", root.base + "/events"]
    stdout: SplitParser { onRead: line => root.onEvent(line) }
    onExited: {
      root.online = false
      root.meters = []
      if (root.active) retry.start()
    }
  }

  Timer {
    id: retry
    interval: 2000
    onTriggered: root.connect()
  }

  function connect() {
    if (!root.active) return
    refresh()
    events.running = true
  }

  onActiveChanged: {
    if (active) {
      connect()
    } else {
      retry.stop()
      events.running = false
      meters = []
    }
  }

  Component.onCompleted: if (active) connect()
}
