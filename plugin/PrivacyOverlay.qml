import QtQuick

// Privacy effects are applied strictly at the stream pipeline level (before encoding
// and distribution to YouTube / Twitch / Kick).
// The physical monitor display remains 100% untouched, clear, and interactive so the
// streamer can continue coding normally while streaming.
Item {
  id: root
  visible: false
  width: 0
  height: 0
}
