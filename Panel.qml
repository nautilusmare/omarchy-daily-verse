import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "maurice.daily-verse"
  ipcTarget: "maurice.daily-verse"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // Hide first so the panel can never get stuck open if the cosmetic
  // hover-suppression below throws (the bar exposes that property
  // read-only in some shells, which used to lock the whole session).
  function open() {
    root.controller.show()
    try { setCenterHoverRevealSuppressed(false) } catch (e) {}
    if (root.verseText === "") root.ensureLoaded()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    if (root.verseText === "") root.ensureLoaded()
    Qt.callLater(function() {
      if (root.opened) try { setCenterHoverRevealSuppressed(true) } catch (e) {}
    })
  }

  function close() {
    root.controller.hide()
    try { setCenterHoverRevealSuppressed(false) } catch (e) {}
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function closeForPopoutSwitch() {
    root.close()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // ---- settings ----
  readonly property string translation: setting("translation", "BSB")
  readonly property string commentaryPref: setting("commentary", "matthew-henry")

  // ---- state ----
  property var verses: []
  property var current: ({ "book": "JHN", "chapter": 3, "verse": 16 })
  property string verseText: ""
  property string verseRef: "JHN 3:16"
  property string commentaryText: ""
  property string commentaryUsed: ""
  property bool loading: false
  property string errorText: ""
  property var chain: ["matthew-henry", "jamieson-fausset-brown"]
  property int chainIndex: 0
  property string loadedDayKey: ""
  property string loadedTranslation: ""
  property string loadedCommentaryPref: ""
  // Collapsed shows a short summary; expanded opens a height-capped reading box
// so the panel grows by a fixed amount instead of by the commentary length.
  property bool commentaryExpanded: false
  readonly property int commentarySummaryAt: 240
  readonly property int commentaryReadHeight: Style.space(300)
  readonly property int commentaryScrollWidth: Style.space(6)
  readonly property bool commentaryTruncated: root.commentaryText !== ""
    && Model.summarize(root.commentaryText, root.commentarySummaryAt).length < root.commentaryText.length
  readonly property string webCommentaryUrl: root.commentaryUsed !== "" && root.current
    ? Model.webCommentaryUrl(root.commentaryUsed, root.current.book, root.current.chapter)
    : ""
  readonly property int scrollbarWidth: Style.space(6)

  readonly property string tooltipText: root.verseText !== "" ? root.verseRef + " — " + root.verseText.slice(0, 80) : "Daily verse"

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  // Offline fallback so the bar/panel never renders empty.
  readonly property string fallbackVerseText: "For God so loved the world that He gave His one and only Son, that everyone who believes in Him shall not perish but have eternal life."

  function refresh() {
    root.ensureLoaded()
  }

  function ensureLoaded() {
    if (root.verses.length === 0) {
      // verses.json not parsed yet; FileView onLoaded will call loadDaily.
      return
    }
    var key = Model.dateKey(new Date())
    if (root.loadedDayKey !== key || root.verseText === "") {
      loadDaily()
    }
  }

  // Refetch the same verse when the translation changes (in-panel cycler or
  // hand-edited shell.json). setCurrent never writes settings, so no loop.
  onSettingsChanged: {
    var t = setting("translation", "BSB")
    if (t !== root.loadedTranslation && root.verses.length > 0 && root.current) {
      root.setCurrent(root.current)
      return
    }
    var c = setting("commentary", "matthew-henry")
    if (c !== root.loadedCommentaryPref && root.verses.length > 0 && root.current && root.verseText !== "") {
      root.restartCommentary(c)
    }
  }

  function restartCommentary(preferred) {
    root.loadedCommentaryPref = preferred
    root.chain = Model.fallbackChain(preferred).filter(function(id) {
      return Model.commentaryAvailable(id, root.current.book)
    })
    if (root.chain.length === 0) root.chain = ["jamieson-fausset-brown", "john-gill"]
    root.chainIndex = 0
    root.commentaryText = ""
    root.commentaryUsed = ""
    root.commentaryExpanded = false
    root.loading = true
    root.startCommentary()
  }

  // Persist an explicit commentary choice (from the dropdown) and refetch
  // commentary for the same verse. restartCommentary runs first so the
  // settings write-back is a no-op in onSettingsChanged.
  function setCommentary(next) {
    if (next === root.loadedCommentaryPref || !root.current) return
    root.restartCommentary(next)
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry["commentary"] = next
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setCurrent(v) {
    root.current = v
    root.verseRef = Model.shortRef(v)
    root.loadedTranslation = root.translation
    root.loadedCommentaryPref = root.commentaryPref
    root.verseText = ""
    root.commentaryText = ""
    root.commentaryUsed = ""
    root.commentaryExpanded = false
    root.errorText = ""
    root.chain = Model.fallbackChain(root.commentaryPref).filter(function(id) {
      return Model.commentaryAvailable(id, v.book)
    })
    if (root.chain.length === 0) root.chain = ["jamieson-fausset-brown", "john-gill"]
    root.chainIndex = 0
    root.loading = true
    verseProc.command = ["curl", "-fsS", "--max-time", "10", Model.verseUrl(root.translation, v.book, v.chapter)]
    verseProc.running = true
  }

  function startCommentary() {
    if (root.chainIndex >= root.chain.length) {
      root.loading = false
      return
    }
    var id = root.chain[root.chainIndex]
    commProc.command = ["curl", "-fsS", "--max-time", "10", Model.commentaryUrl(id, root.current.book, root.current.chapter)]
    commProc.running = true
  }

  // Persist an explicit translation choice (from the dropdown) and refetch
  // the same verse. Guard first: the settings assignment below fires
  // onSettingsChanged synchronously.
  function setTranslation(next) {
    if (next === root.loadedTranslation) return
    root.loadedTranslation = next
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry["translation"] = next
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    if (root.verses.length > 0 && root.current) root.setCurrent(root.current)
  }

  function copyVerse() {
    if (root.verseText === "" || !root.bar) return
    root.bar.run("wl-copy " + Model.copyText(root.verseRef, root.verseText, root.translation))
    copyFeedback.restart()
  }

  // Toggle the in-app reading box. Collapsing resets both scrollers so the
  // next expand starts at the top of the commentary.
  function toggleCommentary() {
    root.commentaryExpanded = !root.commentaryExpanded
    if (!root.commentaryExpanded) {
      commentaryFlick.contentY = 0
      scroller.contentY = 0
    }
  }

  // Full commentary opens in the browser (Bible Hub) for good reading
  // typography instead of scrolling through it in the panel.
  function openWebCommentary() {
    if (root.webCommentaryUrl === "" || !root.bar) return
    root.bar.run("xdg-open " + Model.shellEscape(root.webCommentaryUrl))
  }

  function loadDaily() {
    var key = Model.dateKey(new Date())
    var v = Model.pickDaily(root.verses, key)
    if (!v) return
    root.loadedDayKey = key
    root.setCurrent(v)
  }

  function loadRandom() {
    if (root.verses.length === 0) return
    var v = Model.pickRandom(root.verses, root.current)
    if (!v) return
    root.loadedDayKey = Model.dateKey(new Date())
    root.setCurrent(v)
    if (!root.opened) root.openFromHotkey()
  }

  FileView {
    id: versesFile
    path: Qt.resolvedUrl("verses.json")
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var parsed = JSON.parse(text())
        if (parsed && parsed.length > 0) {
          root.verses = parsed
          if (root.verseText === "") root.loadDaily()
        }
      } catch (e) {
        root.errorText = "Could not parse verses.json"
      }
    }
    onLoadFailed: {
      root.errorText = "Could not load verses.json"
    }
  }


  Process {
    id: verseProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) {
          if (root.current.book === "JHN" && root.current.chapter === 3 && root.current.verse === 16) {
            root.verseText = root.fallbackVerseText
            root.errorText = "Offline — showing saved text."
          } else {
            root.verseText = ""
            root.errorText = "Verse fetch failed (network?). Press ↻ to retry."
            root.loading = false
            return
          }
        } else {
          try {
            var parsed = JSON.parse(raw)
            var t = Model.findVerseText(parsed, root.current.verse)
            if (t !== "") {
              root.verseText = t
              root.errorText = ""
            } else {
              root.errorText = "Verse not found in chapter response."
              root.loading = false
              return
            }
          } catch (e) {
            root.errorText = "Verse parse failed. Press ↻ to retry."
            root.loading = false
            return
          }
        }
        root.startCommentary()
      }
    }
  }

  Process {
    id: commProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var id = root.chain[root.chainIndex] || ""
        var raw = String(text || "").trim()
        var found = ""
        if (raw !== "") {
          try {
            var parsed = JSON.parse(raw)
            found = Model.findCommentary(parsed, root.current.verse)
          } catch (e) {
            found = ""
          }
        }
        if (found !== "") {
          root.commentaryText = found
          root.commentaryUsed = id
          root.loading = false
        } else {
          root.chainIndex++
          if (root.chainIndex < root.chain.length) {
            root.startCommentary()
          } else {
            root.loading = false
            root.commentaryText = ""
            root.commentaryUsed = ""
          }
        }
      }
    }
  }

  // Re-resolve at midnight without reopening.
  Timer {
    interval: 600000
    running: true
    repeat: true
    onTriggered: {
      var key = Model.dateKey(new Date())
      if (key !== root.loadedDayKey && root.verses.length > 0) root.loadDaily()
    }
  }

  // "Copied ✓" feedback on the copy button.
  Timer {
    id: copyFeedback
    interval: 1500
    repeat: false
  }

  Component.onCompleted: {
    versesFile.reload()
    // Safety net if FileView path fails in some shells: keep default JHN 3:16
    // and fetch it directly after a beat.
    Qt.callLater(function() {
      if (root.verses.length === 0) {
        root.verses = [{ "book": "JHN", "chapter": 3, "verse": 16 }]
        root.loadDaily()
      }
    })
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(body.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // While a dropdown popup owns keys, let it handle Escape/j/k alone.
      blocked: translationDrop.popupOpen || commentaryDrop.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        // Math.max keeps contentHeight from dipping a hair under the viewport, which
        // is what used to make the panel scrollbar flash on with nothing to
        // scroll (contentHeight ended up 0.2px larger than height).
        contentHeight: Math.max(body.implicitHeight, height)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: scroller.contentHeight > scroller.height + 1

        Column {
          id: body
          // 3px breathing room: bordered controls (buttons, dropdown
          // triggers) can paint up to ~2px outside their bounds, which the
          // Flickable's clip would otherwise shave off at the edges. The
          // right gutter keeps the custom scrollbar clear of the text.
          x: 3
          width: parent.width - 6 - root.scrollbarWidth
          spacing: Style.space(6)

          // ---- Scripture: reference + translation tag ----
          Row {
            width: parent.width
            spacing: Style.space(4)

            Text {
              text: root.verseRef
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              wrapMode: Text.WordWrap
            }

            Text {
              anchors.baseline: parent.children[0].baseline
              text: "· " + Model.translationLabel(root.translation)
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              opacity: 0.65
              wrapMode: Text.WordWrap
            }
          }

// ---- Scripture: italic blockquote (no vertical line) ----
          Text {
            id: verseTextBody
            width: parent.width
            topPadding: Style.space(6)
            bottomPadding: Style.space(6)
            text: root.loading && root.verseText === "" ? "Loading…" : (root.verseText !== "" ? "\u201C" + root.verseText + "\u201D" : (root.errorText !== "" ? root.errorText : "No verse loaded."))
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body + 5
            font.italic: true
            wrapMode: Text.WordWrap
            lineHeight: 1.10
            opacity: 0.88
          }

          PanelSeparator {
            width: parent.width
          }

          // ---- Commentary: clearly labeled, smaller, slightly dimmed ----
          PanelSectionHeader {
            width: parent.width
            visible: root.commentaryUsed !== ""
            text: root.commentaryUsed !== "" ? "Commentary · " + Model.commentaryName(root.commentaryUsed) : ""
          }

          // One always-visible wrapper owns the commentary height. The
          // enclosing Column measures its children and skips invisible ones
          // without re-measuring when they reappear, so toggling `visible` on a
          // sibling left the panel sized for the collapsed text while the tall
          // reading box was clipped. A single visible box whose implicitHeight
          // merely changes sidesteps that.
          Item {
            id: commentaryReader
            width: parent.width
            implicitHeight: root.commentaryExpanded
              ? Math.min(commentaryFull.implicitHeight, root.commentaryReadHeight)
              : commentarySummary.implicitHeight
            height: implicitHeight
            clip: true

            // Collapsed: short summary cut at a sentence boundary so it reads
            // as a finished thought.
            Text {
              id: commentarySummary
              width: parent.width
              visible: !root.commentaryExpanded
              text: root.commentaryText !== ""
                ? Model.summarize(root.commentaryText, root.commentarySummaryAt)
                : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
              lineHeight: 1.35
              opacity: 0.92
            }

            // Expanded: capped reading box with its own scrollbar, so the panel
            // grows by a fixed amount instead of by the commentary length.
            Flickable {
              id: commentaryFlick
              anchors.fill: parent
              visible: root.commentaryExpanded
              contentWidth: width
              contentHeight: commentaryFull.implicitHeight
              boundsBehavior: Flickable.StopAtBounds
              interactive: commentaryFull.implicitHeight > height

              Text {
                id: commentaryFull
                // Right gutter keeps the text clear of the inner scrollbar.
                width: commentaryFlick.width - root.commentaryScrollWidth - Style.space(4)
                text: root.commentaryText
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
                lineHeight: 1.35
                opacity: 0.92
              }
            }

            // Clicking the expanded text collapses back to the summary.
            TapHandler {
              enabled: root.commentaryExpanded
              onTapped: root.toggleCommentary()
              cursorShape: Qt.PointingHandCursor
            }

            // Slim inner scrollbar, mirroring the panel's own.
            Item {
              id: commentaryScroll
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.right: parent.right
              width: root.commentaryScrollWidth
              visible: root.commentaryExpanded && commentaryFlick.contentHeight > commentaryFlick.height + 1
              opacity: commentaryScrollMouse.containsMouse || commentaryScrollMouse.pressed ? 1.0 : 0.85

              Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

              function jumpTo(y) {
                var trackH = commentaryScroll.height
                var knobH = Math.max(Style.space(24), commentaryFlick.visibleArea.heightRatio * trackH)
                var maxY = trackH - knobH
                var frac = maxY > 0 ? Math.min(1, Math.max(0, (y - knobH / 2) / maxY)) : 0
                commentaryFlick.contentY = frac * (commentaryFlick.contentHeight - commentaryFlick.height)
              }

              Rectangle {
                width: parent.width
                height: Math.max(Style.space(24), commentaryFlick.visibleArea.heightRatio * commentaryScroll.height)
                y: commentaryFlick.visibleArea.yPosition * commentaryScroll.height
                radius: height / 2
                color: commentaryScrollMouse.pressed
                  ? Color.accent
                  : Util.alpha(root.contentForeground, commentaryScrollMouse.containsMouse ? 0.6 : 0.3)
              }

              MouseArea {
                id: commentaryScrollMouse
                anchors.fill: parent
                hoverEnabled: true
                onPressed: function(e) { commentaryScroll.jumpTo(e.y) }
                onPositionChanged: function(e) { if (commentaryScrollMouse.pressed) commentaryScroll.jumpTo(e.y) }
              }
            }
          }

          Flow {
            width: parent.width
            spacing: Style.space(8)

            Button {
              visible: root.commentaryText !== "" && (root.commentaryTruncated || root.commentaryExpanded)
              text: root.commentaryExpanded ? "Show less ▴" : "Show more ▾"
              tooltipText: root.commentaryExpanded ? "Collapse to the short summary" : "Read the full commentary here"
              bordered: true
              focusable: true
              onClicked: root.toggleCommentary()
            }

            Button {
              visible: root.commentaryText !== "" && root.webCommentaryUrl !== ""
              text: "Read full commentary ↗"
              tooltipText: "Open the full commentary in your browser"
              bordered: true
              focusable: true
              onClicked: root.openWebCommentary()
            }
          }

          Text {
            width: parent.width
            visible: !root.loading && root.commentaryText === "" && root.verseText !== ""
            text: "No Reformed commentary found for this verse in the bundled sources (tried MH → JFB → Gill → Calvin → Keil-Delitzsch)."
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            opacity: 0.75
          }

          Text {
            width: parent.width
            text: Model.translationLabel(root.translation) + " via bible.helloao.org · Full commentary on Bible Hub"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            opacity: 0.6
          }

          // ---- Sources: pick translation & commentary directly ----
          // Full-width stacked: immune to font-scale clipping.
          Column {
            width: parent.width
            spacing: Style.space(6)

            Dropdown {
              id: translationDrop
              width: parent.width
              label: "Translation"
              value: root.translation
              options: Model.translationOptions()
              onChanged: function(v) { root.setTranslation(v) }
            }

            Dropdown {
              id: commentaryDrop
              width: parent.width
              label: "Commentary"
              value: root.commentaryUsed !== "" ? root.commentaryUsed : root.commentaryPref
              options: Model.commentaryOptions()
              onChanged: function(v) { root.setCommentary(v) }
            }
          }

          Flow {
            width: parent.width
            spacing: Style.space(8)

            Button {
              text: root.loading ? "Loading…" : "↻ New verse"
              focusable: true
              bordered: true
              onClicked: root.loadRandom()
            }

            Button {
              text: copyFeedback.running ? "Copied ✓" : "⧉ Copy"
              tooltipText: "Copy verse to clipboard"
              focusable: true
              bordered: true
              onClicked: root.copyVerse()
            }
          }

          // The Flow above ends exactly at the Column's implicitHeight, so the
          // bordered buttons' stroke paints past it and the Flickable's clip
          // shaves their bottom border. Mirrors the 3px left/right inset.
          Item {
            width: 1
            height: Style.space(3)
          }
        }
      }

      // Slim scrollbar: the attached QtQuick.Controls ScrollBar does not
      // render on this panel, so this one is hand-built. It appears only when
      // the content overflows; a small pill knob tracks the position. Click
      // anywhere on the strip to jump there, or press-drag the knob.
      Item {
        id: scrollBar
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: root.scrollbarWidth
        // Only show when the panel genuinely overflows by more than a pixel; a bare
        // sub-pixel difference rendered a full-height scrollbar that did
        // nothing. The inner commentary box has its own scrollbar for long text.
        visible: scroller.contentHeight > scroller.height + 1
        opacity: scrollMouse.containsMouse || scrollMouse.pressed ? 1.0 : 0.9

        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        function jumpTo(y) {
          var trackH = scrollBar.height
          var knobH = Math.max(Style.space(24), scroller.visibleArea.heightRatio * trackH)
          var maxY = trackH - knobH
          var frac = maxY > 0 ? Math.min(1, Math.max(0, (y - knobH / 2) / maxY)) : 0
          scroller.contentY = frac * (scroller.contentHeight - scroller.height)
        }




        Rectangle {
          id: scrollKnob
          width: parent.width
          height: Math.max(Style.space(24), scroller.visibleArea.heightRatio * scrollBar.height)
          y: scroller.visibleArea.yPosition * scrollBar.height
          radius: height / 2
          color: scrollMouse.pressed
            ? Color.accent
            : Util.alpha(root.contentForeground, scrollMouse.containsMouse ? 0.6 : 0.3)
        }

        MouseArea {
          id: scrollMouse
          anchors.fill: parent
          hoverEnabled: true
          onPressed: function(e) { scrollBar.jumpTo(e.y) }
          onPositionChanged: function(e) { if (scrollMouse.pressed) scrollBar.jumpTo(e.y) }
        }
      }
    }
  }
}
