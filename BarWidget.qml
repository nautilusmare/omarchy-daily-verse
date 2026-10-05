import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "maurice.daily-verse"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function newVerse() {
    if (panelLoader.item && panelLoader.item.loadRandom) panelLoader.item.loadRandom()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // NOTE: no IpcHandler here (unlike omarchy.clock). Summon/hide/toggle
  // routing works through open()/close()/opened on this root, same as
  // omarchy.weather. This also keeps qmllint happy for files outside the
  // shell tree (qmllint 1.0 crashes on typed IpcHandler functions when the
  // file is not under the -I dir).

  // Show only the icon in the bar — short enough to sit next to weather.
  // The reference and first 80 chars appear as the tooltip instead.
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: true
    hasVisualContent: true
    horizontalMargin: 8
    tooltipText: panelLoader.item ? panelLoader.item.tooltipText : "Daily verse"
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.newVerse()
      else root.togglePanel()
    }
  }
}
