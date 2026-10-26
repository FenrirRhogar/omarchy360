.pragma library

// Pure helpers for the apps page. Node properties are only read once a node is
// bound (ready): reading them earlier can destabilize Quickshell's PipeWire
// service, the same caveat Omarchy's own audio panel works around.

function props(node) {
  return node && node.ready && node.properties ? node.properties : {}
}

function truthy(v) {
  return v === true || v === "true" || v === 1
}

// App streams, minus loopback plumbing (e.g. capture.ssl12_in1, virtual and
// passive) and meter taps (Quickshell's peak monitors, our omarchy360-meter).
function isAppStream(node) {
  if (!node || !node.isStream || !node.audio) return false
  var p = props(node)
  if (!node.ready || node.name === "quickshell" || String(node.name).indexOf("omarchy360-meter") === 0) return false
  return !truthy(p["node.virtual"]) && !truthy(p["node.passive"]) && !truthy(p["stream.monitor"])
}

function usesAuxChannels(node) {
  return String(props(node)["audio.position"] || "").indexOf("AUX") !== -1
}

function sameNodes(a, b) {
  if (a.length !== b.length) return false
  for (var i = 0; i < a.length; i++) if (a[i] !== b[i]) return false
  return true
}

function nodeLabel(node) {
  if (!node) return "?"
  var p = props(node)
  return node.description || p["node.description"] || node.nickname || node.name || ("node " + node.id)
}

function streamLabel(node) {
  var p = props(node)
  var app = p["application.name"] || node.description || node.name || ("stream " + node.id)
  var media = p["media.name"] || ""
  return media && media !== app ? app + " · " + media : app
}

function streamKind(node) {
  return node && node.isSink ? "play" : "rec"
}

function channelCount(node) {
  var p = props(node)
  var n = parseInt(p["audio.channels"])
  if (n > 0) return n
  return node && node.audio && node.audio.volumes ? node.audio.volumes.length : 0
}

function percent(v) {
  return Math.round(Math.max(0, v) * 100) + "%"
}

// Linear peak -> 0..1 meter position over a -60..0 dBFS window.
function peakPosition(peak) {
  if (!(peak > 0.000001)) return 0
  var db = 20 * Math.log(peak) / Math.LN10
  return Math.max(0, Math.min(1, (db + 60) / 60))
}

function channelLabel(index, count) {
  if (count === 1) return "M"
  if (count === 2) return index === 0 ? "L" : "R"
  return String(index + 1)
}
