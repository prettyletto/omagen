import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Ui
import "." as Bar

BarWidget {
    id: compactTrayRoot
    moduleName: "omarchy.tray"

    property bool expanded: false
    property bool trayMenuOpen: false
    property bool managePopupOpen: false
    property var activeTrayItem: null
    property var activeTrayAnchor: null
    property var submenuStack: []
    property bool menuLevelSettling: false
    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property var pinnedIds: settings && settings.pinned instanceof Array ? settings.pinned : []
    readonly property var hiddenIds: settings && settings.hidden instanceof Array ? settings.hidden : []
    readonly property var pinnedItems: compactTrayRoot.bucket("pinned")
    readonly property var drawerItems: compactTrayRoot.bucket("drawer")
    readonly property var allItems: compactTrayRoot.bucket("all")
    readonly property int drawerCount: drawerItems.length
    readonly property bool hasItems: pinnedItems.length > 0 || drawerCount > 0
    readonly property bool vertical: bar.vertical
    readonly property int itemExtent: Style.bar.iconSlot
    readonly property int submenuDepth: submenuStack.length
    readonly property string currentMenuTitle: submenuDepth > 0 ? submenuStack[submenuDepth - 1].title : ""
    readonly property var currentMenuChildren: submenuDepth > 0
        ? submenuStack[submenuDepth - 1].opener.children
        : trayMenuOpener.children

    function itemNamed(item, name) {
        if (!item) return false
        var needle = String(name || "").toLowerCase()
        return String(item.id || "").toLowerCase().indexOf(needle) !== -1
            || String(item.title || "").toLowerCase().indexOf(needle) !== -1
            || String(item.tooltipTitle || "").toLowerCase().indexOf(needle) !== -1
    }

    function layoutHasWidget(layout, id) {
        var sections = ["left", "center", "right"]
        for (var section = 0; section < sections.length; section++) {
            var entries = layout && layout[sections[section]]
            if (!Array.isArray(entries)) continue
            for (var index = 0; index < entries.length; index++)
                if (bar.entryId(entries[index]) === id) return true
        }
        return false
    }

    function ownedByOmarchy(item) {
        var layout = compactTrayRoot.bar && compactTrayRoot.bar.layoutConfig
            ? compactTrayRoot.bar.layoutConfig : bar.layoutConfig
        return compactTrayRoot.itemNamed(item, "localsend")
            || (compactTrayRoot.layoutHasWidget(layout, "omarchy.dropbox")
                && compactTrayRoot.itemNamed(item, "dropbox"))
    }

    function classifyItem(item) {
        var itemId = String(item && item.id || "")
        if (compactTrayRoot.hiddenIds.indexOf(itemId) !== -1) return "hidden"
        if (compactTrayRoot.pinnedIds.indexOf(itemId) !== -1) return "pinned"
        return "drawer"
    }

    function bucket(category) {
        var values = SystemTray.items.values
        var result = []
        for (var index = 0; index < values.length; index++) {
            var item = values[index]
            if (!item || item.status === Status.Passive || compactTrayRoot.ownedByOmarchy(item)) continue
            if (category === "all") {
                result.push(item)
                continue
            }
            if (compactTrayRoot.classifyItem(item) === category)
                result.push(item)
        }
        return result
    }

    function persistTrayState(pinned, hidden) {
        if (!compactTrayRoot.bar || !compactTrayRoot.bar.shell
                || typeof compactTrayRoot.bar.shell.updateEntryInline !== "function") return
        compactTrayRoot.bar.shell.updateEntryInline("omarchy.tray", {
            id: "omarchy.tray", pinned: pinned, hidden: hidden
        })
    }

    function togglePin(itemId) {
        var pinned = compactTrayRoot.pinnedIds.slice()
        var hidden = compactTrayRoot.hiddenIds.slice()
        var index = pinned.indexOf(itemId)
        if (index !== -1) pinned.splice(index, 1)
        else {
            pinned.push(itemId)
            var hiddenIndex = hidden.indexOf(itemId)
            if (hiddenIndex !== -1) hidden.splice(hiddenIndex, 1)
        }
        compactTrayRoot.persistTrayState(pinned, hidden)
    }

    function toggleHide(itemId) {
        var pinned = compactTrayRoot.pinnedIds.slice()
        var hidden = compactTrayRoot.hiddenIds.slice()
        var index = hidden.indexOf(itemId)
        if (index !== -1) hidden.splice(index, 1)
        else {
            hidden.push(itemId)
            var pinnedIndex = pinned.indexOf(itemId)
            if (pinnedIndex !== -1) pinned.splice(pinnedIndex, 1)
        }
        compactTrayRoot.persistTrayState(pinned, hidden)
    }

    function iconIsSymbolic(icon) {
        var name = String(icon || "").split("?")[0]
        return name.slice(-9) === "-symbolic"
    }

    visible: hasItems
    implicitWidth: vertical ? bar.barSize
        : (hasItems ? itemExtent * (1 + pinnedItems.length + (expanded ? drawerCount : 0)) : 0)
    implicitHeight: vertical
        ? (hasItems ? itemExtent * (1 + pinnedItems.length + (expanded ? drawerCount : 0)) : 0)
        : bar.barSize
    width: implicitWidth
    height: implicitHeight

    Behavior on width {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Component {
        id: submenuOpenerComponent
        QsMenuOpener {}
    }

    Timer {
        id: menuLevelSettleTimer
        interval: 250
        onTriggered: compactTrayRoot.menuLevelSettling = false
    }

    function resetTrayMenu() {
        menuLevelSettling = false
        menuLevelSettleTimer.stop()
        if (trayMenuFlick) trayMenuFlick.contentY = 0
        var openers = submenuStack
        submenuStack = []
        for (var i = openers.length - 1; i >= 0; i--)
            if (openers[i] && openers[i].opener) openers[i].opener.destroy()
    }

    function enterSubmenu(entry, title) {
        var opener = submenuOpenerComponent.createObject(compactTrayRoot, { menu: entry })
        if (!opener) return
        var stack = submenuStack.slice()
        stack.push({ opener: opener, title: title })
        submenuStack = stack
        menuLevelSettling = true
        menuLevelSettleTimer.restart()
    }

    function leaveSubmenu() {
        if (submenuStack.length === 0) return
        var stack = submenuStack.slice()
        var top = stack.pop()
        submenuStack = stack
        if (top && top.opener) top.opener.destroy()
        menuLevelSettling = true
        menuLevelSettleTimer.restart()
    }

    function openTrayMenu(item, anchorItem, mouse) {
        if (!item || !anchorItem || !anchorItem.QsWindow) return
        if (!item.menu) {
            if (!item.display) return
            var trayWindow = anchorItem.QsWindow
            var point = trayWindow.contentItem.mapFromItem(anchorItem, mouse.x, mouse.y)
            item.display(trayWindow.window, point.x, point.y)
            return
        }
        resetTrayMenu()
        activeTrayItem = item
        activeTrayAnchor = anchorItem
        trayMenuOpen = true
    }

    function close() {
        trayMenuOpen = false
        managePopupOpen = false
    }

    // Match native Quattro: the drawer follows the pointer, while the
    // click remains available as an explicit toggle for touchpads and
    // keyboard-driven pointer users.
    HoverHandler {
        onHoveredChanged: compactTrayRoot.expanded = hovered
    }

    Rectangle {
        id: compactTraySurface
        anchors.fill: parent
        color: bar.topology === "islands"
            ? "transparent"
            : (bar.transparent ? "transparent" : Util.alpha(bar.surfaceColor, bar.surfaceOpacity))
        radius: bar.barSize / 2
        border.width: bar.topology === "islands" ? 0 : bar.borderWidth
        border.color: !bar.transparent && bar.borderWidth > 0
            ? Util.alpha(bar.borderColor, bar.borderOpacity)
            : "transparent"
    }

    Item {
        id: compactTrayChevron
        width: compactTrayRoot.vertical ? parent.width : compactTrayRoot.itemExtent
        height: compactTrayRoot.vertical ? compactTrayRoot.itemExtent : parent.height
        x: compactTrayRoot.vertical ? 0 : parent.width - width
        anchors.top: compactTrayRoot.vertical ? parent.top : undefined

        Text {
            anchors.centerIn: parent
            // Compact vertical rails keep the tray entry at the top;
            // the collapsed affordance points upward toward the tray.
            text: compactTrayRoot.vertical
                ? (compactTrayRoot.expanded ? "\uf077" : "\uf078")
                : (compactTrayRoot.expanded ? "\uf053" : "\uf054")
            color: compactTrayRoot.foreground
            font.family: compactTrayRoot.fontFamily
            font.pixelSize: Style.bar.iconFont
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    compactTrayRoot.managePopupOpen = !compactTrayRoot.managePopupOpen
                    mouse.accepted = true
                }
            }
            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton
                        && !(bar.topology === "minimal" && compactTrayRoot.vertical))
                    compactTrayRoot.expanded = !compactTrayRoot.expanded
                else if (mouse.button === Qt.RightButton)
                    mouse.accepted = true
            }
        }
    }

    Row {
        id: compactTrayIcons
        x: compactTrayChevron.x - width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        visible: !compactTrayRoot.vertical && compactTrayRoot.expanded && compactTrayRoot.drawerCount > 0

        Repeater {
            model: compactTrayRoot.drawerItems
            delegate: Item {
                id: horizontalTrayItem
                required property var modelData
                width: compactTrayRoot.itemExtent
                height: compactTrayRoot.itemExtent

                function displayMenu(mouse) {
                    compactTrayRoot.openTrayMenu(modelData, horizontalTrayItem, mouse)
                }

                readonly property bool tooltipHovered: horizontalTrayMouse.containsMouse

                CompactTrayIcon {
                    anchors.centerIn: parent
                    width: Style.space(13)
                    height: Style.space(13)
                    icon: modelData.icon
                    trayHost: compactTrayRoot
                }

                MouseArea {
                    id: horizontalTrayMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (compactTrayRoot.bar) compactTrayRoot.bar.showTooltip(horizontalTrayItem, modelData.tooltipTitle || modelData.title || modelData.id || "")
                    onExited: if (compactTrayRoot.bar) compactTrayRoot.bar.hideTooltip(horizontalTrayItem)
                    onPressed: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            horizontalTrayItem.displayMenu(mouse)
                            mouse.accepted = true
                        }
                    }
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            mouse.accepted = true
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate()
                        } else if (modelData.onlyMenu) {
                            horizontalTrayItem.displayMenu(mouse)
                        } else {
                            modelData.activate()
                        }
                    }
                    onWheel: function(wheel) { modelData.scroll(wheel.angleDelta.y, false) }
                }
            }
        }
    }

    Row {
        id: compactTrayPinned
        x: parent.width - width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
            model: compactTrayRoot.pinnedItems
            delegate: Item {
                id: horizontalPinnedTrayItem
                required property var modelData
                width: compactTrayRoot.itemExtent
                height: compactTrayRoot.itemExtent

                function displayMenu(mouse) {
                    compactTrayRoot.openTrayMenu(modelData, horizontalPinnedTrayItem, mouse)
                }

                readonly property bool tooltipHovered: horizontalPinnedTrayMouse.containsMouse

                CompactTrayIcon {
                    anchors.centerIn: parent
                    width: Style.space(13)
                    height: Style.space(13)
                    icon: modelData.icon
                    trayHost: compactTrayRoot
                }

                MouseArea {
                    id: horizontalPinnedTrayMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (compactTrayRoot.bar) compactTrayRoot.bar.showTooltip(horizontalPinnedTrayItem, modelData.tooltipTitle || modelData.title || modelData.id || "")
                    onExited: if (compactTrayRoot.bar) compactTrayRoot.bar.hideTooltip(horizontalPinnedTrayItem)
                    onPressed: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            horizontalPinnedTrayItem.displayMenu(mouse)
                            mouse.accepted = true
                        }
                    }
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            mouse.accepted = true
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate()
                        } else if (modelData.onlyMenu) {
                            horizontalPinnedTrayItem.displayMenu(mouse)
                        } else {
                            modelData.activate()
                        }
                    }
                    onWheel: function(wheel) { modelData.scroll(wheel.angleDelta.y, false) }
                }
            }
        }
    }

    Column {
        id: compactTrayVerticalIcons
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: compactTrayChevron.bottom
        spacing: 0
        visible: compactTrayRoot.vertical && compactTrayRoot.expanded

        Repeater {
            model: compactTrayRoot.drawerItems
            delegate: Item {
                id: verticalTrayItem
                required property var modelData
                width: compactTrayRoot.itemExtent
                height: compactTrayRoot.itemExtent

                function displayMenu(mouse) {
                    compactTrayRoot.openTrayMenu(modelData, verticalTrayItem, mouse)
                }

                readonly property bool tooltipHovered: verticalTrayMouse.containsMouse

                CompactTrayIcon {
                    anchors.centerIn: parent
                    width: Style.space(13)
                    height: Style.space(13)
                    icon: modelData.icon
                    trayHost: compactTrayRoot
                }

                MouseArea {
                    id: verticalTrayMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (compactTrayRoot.bar) compactTrayRoot.bar.showTooltip(verticalTrayItem, modelData.tooltipTitle || modelData.title || modelData.id || "")
                    onExited: if (compactTrayRoot.bar) compactTrayRoot.bar.hideTooltip(verticalTrayItem)
                    onPressed: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            verticalTrayItem.displayMenu(mouse)
                            mouse.accepted = true
                        }
                    }
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            mouse.accepted = true
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate()
                        } else if (modelData.onlyMenu) {
                            verticalTrayItem.displayMenu(mouse)
                        } else {
                            modelData.activate()
                        }
                    }
                    onWheel: function(wheel) { modelData.scroll(wheel.angleDelta.y, false) }
                }
            }
        }
    }

    Column {
        id: compactTrayPinnedVertical
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: compactTrayRoot.expanded ? compactTrayVerticalIcons.bottom : compactTrayChevron.bottom
        spacing: 0

        Repeater {
            model: compactTrayRoot.pinnedItems
            delegate: Item {
                id: verticalPinnedTrayItem
                required property var modelData
                width: compactTrayRoot.itemExtent
                height: compactTrayRoot.itemExtent

                function displayMenu(mouse) {
                    compactTrayRoot.openTrayMenu(modelData, verticalPinnedTrayItem, mouse)
                }

                readonly property bool tooltipHovered: verticalPinnedTrayMouse.containsMouse

                CompactTrayIcon {
                    anchors.centerIn: parent
                    width: Style.space(13)
                    height: Style.space(13)
                    icon: modelData.icon
                    trayHost: compactTrayRoot
                }

                MouseArea {
                    id: verticalPinnedTrayMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (compactTrayRoot.bar) compactTrayRoot.bar.showTooltip(verticalPinnedTrayItem, modelData.tooltipTitle || modelData.title || modelData.id || "")
                    onExited: if (compactTrayRoot.bar) compactTrayRoot.bar.hideTooltip(verticalPinnedTrayItem)
                    onPressed: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            verticalPinnedTrayItem.displayMenu(mouse)
                            mouse.accepted = true
                        }
                    }
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            mouse.accepted = true
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate()
                        } else if (modelData.onlyMenu) {
                            verticalPinnedTrayItem.displayMenu(mouse)
                        } else {
                            modelData.activate()
                        }
                    }
                    onWheel: function(wheel) { modelData.scroll(wheel.angleDelta.y, false) }
                }
            }
        }
    }

    // Keep the native tray-management affordance available in every
    // replacement form. Without this, pinned/hidden settings existed in
    // shell.json but could not be changed from the generated bar.
    PopupCard {
        id: managePopup
        anchorItem: compactTrayRoot
        owner: compactTrayRoot
        bar: compactTrayRoot.bar
        open: compactTrayRoot.managePopupOpen
        contentWidth: managePopup.fittedContentWidth(Style.space(300))
        contentHeight: managePopup.fittedContentHeight(manageColumn.implicitHeight)

        Column {
            id: manageColumn
            anchors.fill: parent
            spacing: Style.space(8)

            Text {
                text: "Tray icons"
                color: compactTrayRoot.foreground
                font.family: compactTrayRoot.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
            }

            Text {
                text: "Pinned icons stay visible. Hidden icons never show."
                color: Qt.darker(compactTrayRoot.foreground, 1.4)
                font.family: compactTrayRoot.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Text {
                visible: compactTrayRoot.allItems.length === 0
                text: "No tray items reporting."
                color: Qt.darker(compactTrayRoot.foreground, 1.5)
                font.family: compactTrayRoot.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.italic: true
            }

            Repeater {
                model: compactTrayRoot.allItems
                delegate: Item {
                    id: trayManageRow
                    required property var modelData
                    width: manageColumn.width
                    implicitHeight: Style.space(28)

                    readonly property string itemId: String(modelData.id || "")
                    readonly property string displayName: {
                        var title = String(modelData.title || "").trim()
                        if (title) return title
                        var tooltip = String(modelData.tooltipTitle || "").trim()
                        if (tooltip) return tooltip
                        var id = trayManageRow.itemId
                        var slash = id.lastIndexOf("/")
                        return slash !== -1 ? id.substring(slash + 1) : (id || "Unknown")
                    }
                    readonly property bool isPinned: compactTrayRoot.pinnedIds.indexOf(itemId) !== -1
                    readonly property bool isHidden: compactTrayRoot.hiddenIds.indexOf(itemId) !== -1

                CompactTrayIcon {
                    id: manageIcon
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    width: Style.space(16)
                    height: Style.space(16)
                    icon: trayManageRow.modelData.icon
                    trayHost: compactTrayRoot
                }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: manageIcon.right
                        anchors.leftMargin: Style.space(10)
                        anchors.right: manageHideButton.left
                        anchors.rightMargin: Style.space(8)
                        text: trayManageRow.displayName
                        color: compactTrayRoot.foreground
                        font.family: compactTrayRoot.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                    }

                    Button {
                        id: managePinButton
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        iconText: "\uf08d"
                        text: trayManageRow.isPinned ? "Unpin" : "Pin"
                        foreground: compactTrayRoot.foreground
                        horizontalPadding: Style.space(8)
                        verticalPadding: Style.space(3)
                        iconSize: Style.font.bodySmall
                        fontSize: Style.font.bodySmall
                        onClicked: compactTrayRoot.togglePin(trayManageRow.itemId)
                    }

                    Button {
                        id: manageHideButton
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: managePinButton.left
                        anchors.rightMargin: Style.space(6)
                        iconText: "\uf06e"
                        text: trayManageRow.isHidden ? "Show" : "Hide"
                        foreground: compactTrayRoot.foreground
                        horizontalPadding: Style.space(8)
                        verticalPadding: Style.space(3)
                        iconSize: Style.font.bodySmall
                        fontSize: Style.font.bodySmall
                        onClicked: compactTrayRoot.toggleHide(trayManageRow.itemId)
                    }
                }
            }
        }
    }

    // Tray items that expose a QsMenuHandle need an in-shell menu. Calling
    // QsMenuEntry.display() for those items asks Quickshell to create a
    // platform menu, but the Omarchy shell is not a QApplication, so that
    // path silently fails (especially for apps whose actions are nested in
    // submenus). Keep the generated tray on the same QML menu contract as
    // the native tray widget.
    QsMenuOpener {
        id: trayMenuOpener
        menu: compactTrayRoot.activeTrayItem ? compactTrayRoot.activeTrayItem.menu : null
    }

    PopupCard {
        id: trayMenuPopup
        anchorItem: compactTrayRoot.activeTrayAnchor || compactTrayRoot
        owner: compactTrayRoot
        bar: compactTrayRoot.bar
        open: compactTrayRoot.trayMenuOpen
        onVisibleChanged: if (!visible) compactTrayRoot.resetTrayMenu()
        padding: Style.space(8)
        borderColor: Qt.rgba(compactTrayRoot.foreground.r, compactTrayRoot.foreground.g, compactTrayRoot.foreground.b, 0.45)
        contentWidth: trayMenuPopup.fittedContentWidth(Style.space(232))
        contentHeight: trayMenuPopup.fittedContentHeight(menuHeader.implicitHeight + trayMenuColumn.implicitHeight, Style.space(420))

        Column {
            id: trayMenuLayout
            anchors.fill: parent
            spacing: 0

            Column {
                id: menuHeader
                visible: compactTrayRoot.submenuDepth > 0
                width: trayMenuLayout.width
                spacing: 0

                Item {
                    width: menuHeader.width
                    implicitHeight: Style.space(30)

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.max(2, Style.cornerRadius)
                        color: backMouse.containsMouse
                            ? Style.hoverFillFor(compactTrayRoot.foreground, compactTrayRoot.foreground)
                            : "transparent"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        width: Style.space(22)
                        horizontalAlignment: Text.AlignHCenter
                        text: "\u2039"
                        color: compactTrayRoot.foreground
                        font.family: compactTrayRoot.fontFamily
                        font.pixelSize: Style.font.bodySmall
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Style.space(28)
                        anchors.right: parent.right
                        anchors.rightMargin: Style.space(10)
                        text: compactTrayRoot.currentMenuTitle
                        color: compactTrayRoot.foreground
                        font.family: compactTrayRoot.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (compactTrayRoot.menuLevelSettling) return
                            trayMenuFlick.contentY = 0
                            compactTrayRoot.leaveSubmenu()
                        }
                    }
                }

                Item {
                    width: menuHeader.width
                    implicitHeight: Style.space(11)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: Style.space(10)
                        anchors.right: parent.right
                        anchors.rightMargin: Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        height: 1
                        color: Color.popups.border
                        opacity: 0.45
                    }
                }
            }

            Flickable {
                id: trayMenuFlick
                width: trayMenuLayout.width
                height: trayMenuLayout.height - (menuHeader.visible ? menuHeader.implicitHeight : 0)
                contentWidth: width
                contentHeight: trayMenuColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: trayMenuColumn
                    width: trayMenuFlick.width
                    spacing: 0

                    Repeater {
                        model: compactTrayRoot.currentMenuChildren

                        delegate: Item {
                            id: menuRow
                            required property var modelData
                            required property int index

                            readonly property string rowText: String(modelData.text || "")
                            readonly property string activeTitle: compactTrayRoot.activeTrayItem
                                ? String(compactTrayRoot.activeTrayItem.title || compactTrayRoot.activeTrayItem.id || "") : ""
                            readonly property bool atRoot: compactTrayRoot.submenuDepth === 0
                            readonly property bool rootTitleEntry: atRoot && index === 0
                                && modelData.hasChildren && rowText.toLowerCase() === activeTitle.toLowerCase()
                            readonly property bool leadingSeparator: atRoot && modelData.isSeparator && index <= 1
                            readonly property bool hiddenRow: rootTitleEntry || leadingSeparator

                            visible: !hiddenRow
                            width: trayMenuColumn.width
                            implicitHeight: hiddenRow ? 0
                                : (modelData.isSeparator ? Style.space(11) : Style.space(30))
                            opacity: modelData.enabled ? 1.0 : 0.45

                            Rectangle {
                                visible: menuRow.modelData.isSeparator
                                anchors.left: parent.left
                                anchors.leftMargin: Style.space(10)
                                anchors.right: parent.right
                                anchors.rightMargin: Style.space(10)
                                anchors.verticalCenter: parent.verticalCenter
                                height: 1
                                color: Color.popups.border
                                opacity: 0.45
                            }

                            Rectangle {
                                visible: !menuRow.modelData.isSeparator
                                anchors.fill: parent
                                radius: Math.max(2, Style.cornerRadius)
                                color: rowMouse.containsMouse && menuRow.modelData.enabled
                                    ? Style.hoverFillFor(compactTrayRoot.foreground, compactTrayRoot.foreground)
                                    : "transparent"
                            }

                            Text {
                                visible: !menuRow.modelData.isSeparator
                                    && menuRow.modelData.buttonType !== QsMenuButtonType.None
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                width: Style.space(22)
                                horizontalAlignment: Text.AlignHCenter
                                text: menuRow.modelData.checkState === Qt.Checked ? "\uf00c" : ""
                                color: compactTrayRoot.foreground
                                font.family: compactTrayRoot.fontFamily
                                font.pixelSize: Style.font.bodySmall
                            }

                            Image {
                                id: menuIcon
                                visible: !menuRow.modelData.isSeparator
                                    && String(menuRow.modelData.icon || "") !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: Style.space(24)
                                width: Style.space(16)
                                height: Style.space(16)
                                fillMode: Image.PreserveAspectFit
                                sourceSize.width: width * Screen.devicePixelRatio
                                sourceSize.height: height * Screen.devicePixelRatio
                                source: menuRow.modelData.icon
                            }

                            Text {
                                visible: !menuRow.modelData.isSeparator
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: menuIcon.visible ? Style.space(46) : Style.space(28)
                                anchors.right: submenuGlyph.left
                                anchors.rightMargin: Style.space(8)
                                text: menuRow.rowText
                                color: compactTrayRoot.foreground
                                font.family: compactTrayRoot.fontFamily
                                font.pixelSize: Style.font.bodySmall
                                elide: Text.ElideRight
                            }

                            Text {
                                id: submenuGlyph
                                visible: !menuRow.modelData.isSeparator && menuRow.modelData.hasChildren
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: Style.space(10)
                                text: "\u203a"
                                color: compactTrayRoot.foreground
                                font.family: compactTrayRoot.fontFamily
                                font.pixelSize: Style.font.bodySmall
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !menuRow.modelData.isSeparator && menuRow.modelData.enabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (compactTrayRoot.menuLevelSettling) return
                                    if (menuRow.modelData.hasChildren) {
                                        trayMenuFlick.contentY = 0
                                        compactTrayRoot.enterSubmenu(menuRow.modelData, menuRow.rowText)
                                    } else {
                                        menuRow.modelData.triggered()
                                        compactTrayRoot.close()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}

