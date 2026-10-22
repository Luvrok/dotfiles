import QtQuick
import Quickshell
import qs

// a calendar: the month with week numbers, mondays first, or the whole
// year. the orange cursor is a day (a month in the year), today is orange.
// h/j/k/l move it, n/p go a month on (a year in the year), y switches the
// year on and off, t comes back to today. the wheel goes through months
// (years), a click picks a day, a month in the year opens it
Menu {
    id: menu

    readonly property var monthNames: ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
    readonly property var dayNames: ["mo", "tu", "we", "th", "fr", "sa", "su"]
    readonly property date today: clock.date
    property date cursor: new Date()
    property bool year: false
    // the last move's direction, the grid slides in from that side
    property int dir: 0

    // a new month or year, the body slides
    signal moved

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // the 42 days of a month's grid, from the monday before the 1st
    function gridDays(y, m) {
        const first = new Date(y, m, 1);
        const start = new Date(y, m, 1 - (first.getDay() + 6) % 7);
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
        return out;
    }

    // iso 8601: the week with the year's first thursday is 1
    function week(d) {
        const t = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 3 - (d.getDay() + 6) % 7);
        const first = new Date(t.getFullYear(), 0, 4);
        return 1 + Math.round(((t - first) / 86400000 - 3 + (first.getDay() + 6) % 7) / 7);
    }

    function go(d) {
        const before = cursor.getFullYear() * 12 + cursor.getMonth();
        const after = d.getFullYear() * 12 + d.getMonth();
        // the year slides when the year changes, the month when the month does
        const step = year ? Math.sign(d.getFullYear() - cursor.getFullYear()) : Math.sign(after - before);
        cursor = d;
        if (step !== 0) {
            dir = step;
            moved();
        }
    }

    function moveDays(n) {
        go(new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + n));
    }

    // months on, the day stays or becomes the month's last
    function moveMonths(n) {
        const y = cursor.getFullYear(), m = cursor.getMonth() + n;
        const last = new Date(y, m + 1, 0).getDate();
        go(new Date(y, m, Math.min(cursor.getDate(), last)));
    }

    title: "calendar"
    icon: "\u{f00ed}"
    // the year is in the grid's title
    status: `${["mon", "tue", "wed", "thu", "fri", "sat", "sun"][(cursor.getDay() + 6) % 7]} ${cursor.getDate()} ${monthNames[cursor.getMonth()].slice(0, 3)} · week ${week(cursor)}`
    lines: 0
    menuWidth: year ? ch(74) : ch(40)
    hints: year ? [["h/j/k/l", "month"], ["n/p", "year"], ["enter", "open"], ["t", "today"], ["esc", "close"]] : [["h/j/k/l", "day"], ["n/p", "month"], ["y", "year"], ["t", "today"], ["esc", "close"]]

    keys: e => {
        const k = e.key;
        const step = year ? [1, 3] : [1, 7];
        const move = n => year ? moveMonths(n) : moveDays(n);
        if (k === Qt.Key_Left || key(e, "h"))
            move(-step[0]);
        else if (k === Qt.Key_Right || key(e, "l"))
            move(step[0]);
        else if (k === Qt.Key_Up || key(e, "k"))
            move(-step[1]);
        else if (k === Qt.Key_Down || key(e, "j"))
            move(step[1]);
        else if (k === Qt.Key_PageDown || key(e, "n"))
            moveMonths(year ? 12 : 1);
        else if (k === Qt.Key_PageUp || key(e, "p"))
            moveMonths(year ? -12 : -1);
        else if (key(e, "t"))
            go(new Date(today));
        else if (key(e, "y") || (year && (k === Qt.Key_Return || k === Qt.Key_Enter)))
            year = !year;
        else
            return false;
        return true;
    }

    body: Component {
        Item {
            id: page

            readonly property real cw: menu.ch(menu.year ? 3 : 4)

            width: parent?.width ?? 0
            implicitHeight: content.implicitHeight + 8
            clip: true

            FontMetrics {
                id: fm
                font: menu.rowFont
            }

            // the wheel goes through months, years in the year
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: w => menu.moveMonths((w.angleDelta.y > 0 ? -1 : 1) * (menu.year ? 12 : 1))
            }

            Item {
                id: content

                implicitHeight: menu.year ? yearView.implicitHeight : monthView.implicitHeight
                width: parent.width
                transform: Translate {
                    id: shift
                }

                MonthGrid {
                    id: monthView
                    visible: !menu.year
                    x: Math.round((page.width - implicitWidth) / 2)
                    y: 4
                    month: menu.cursor.getMonth()
                    yearNumber: menu.cursor.getFullYear()
                    cw: page.cw
                    rh: Math.ceil(fm.height + 6)
                    font: menu.rowFont
                    weeks: true
                    title: `${menu.monthNames[month]} ${yearNumber}`
                    cursorOn: true
                }

                Grid {
                    id: yearView
                    visible: menu.year
                    x: Math.round((page.width - implicitWidth) / 2)
                    y: 4
                    columns: 3
                    columnSpacing: menu.ch(3)
                    rowSpacing: 8

                    Repeater {
                        model: 12

                        delegate: MonthGrid {
                            required property int index
                            month: index
                            yearNumber: menu.cursor.getFullYear()
                            cw: page.cw
                            rh: Math.ceil(fm.height * 0.9 + 2)
                            font.family: menu.rowFont.family
                            font.pointSize: menu.rowFont.pointSize - 1
                            title: menu.monthNames[index]
                            cursorOn: index === menu.cursor.getMonth()
                            onPicked: d => {
                                menu.go(d);
                                menu.year = false;
                            }
                        }
                    }
                }
            }

            // like a tag switch: 6% from the side it comes from, with a fade
            ParallelAnimation {
                id: slide
                NumberAnimation {
                    target: shift
                    property: "x"
                    from: menu.dir * page.width * 0.06
                    to: 0
                    duration: 200
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: content
                    property: "opacity"
                    from: 0.3
                    to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Connections {
                target: menu
                function onMoved() {
                    slide.restart();
                }
            }
        }
    }

    // a month: its name, the day names, 6 weeks. other months' days are
    // dim, today orange, the cursor an orange block that glides. in the
    // year the whole month is the cursor: its name gets the block
    component MonthGrid: Item {
        id: grid

        property int month
        property int yearNumber
        property real cw
        property real rh
        property font font
        property bool weeks: false
        property string title
        // the cursor is in this month
        property bool cursorOn: false
        readonly property var dates: menu.gridDays(yearNumber, month)
        readonly property real pad: weeks ? cw : 0

        signal picked(date d)

        implicitWidth: pad + 7 * cw
        implicitHeight: 8 * rh

        Rectangle {
            visible: grid.cursorOn && menu.year
            width: grid.implicitWidth
            height: grid.rh
            color: Theme.selBg
        }

        Text {
            width: grid.implicitWidth
            height: grid.rh
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: grid.title
            color: grid.cursorOn && menu.year ? Theme.sel : grid.month === menu.today.getMonth() && grid.yearNumber === menu.today.getFullYear() ? Theme.selBg : Theme.fg
            font.family: grid.font.family
            font.pointSize: grid.font.pointSize
            font.bold: true

            MouseArea {
                anchors.fill: parent
                enabled: menu.year
                cursorShape: Qt.PointingHandCursor
                onClicked: grid.picked(new Date(grid.yearNumber, grid.month, 1))
            }
        }

        // week numbers and day names
        Text {
            visible: grid.weeks
            y: grid.rh
            width: grid.cw
            height: grid.rh
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "wk"
            color: Theme.line
            font: grid.font
        }
        Repeater {
            model: menu.dayNames
            delegate: Text {
                required property int index
                required property string modelData
                x: grid.pad + index * grid.cw
                y: grid.rh
                width: grid.cw
                height: grid.rh
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: Theme.dim
                font: grid.font
            }
        }
        Repeater {
            model: grid.weeks ? 6 : 0
            delegate: Text {
                required property int index
                y: (index + 2) * grid.rh
                width: grid.cw
                height: grid.rh
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: menu.week(grid.dates[index * 7])
                color: Theme.line
                font: grid.font
            }
        }

        // the cursor glides from day to day
        Rectangle {
            readonly property int at: grid.dates.findIndex(d => menu.sameDay(d, menu.cursor))
            visible: grid.cursorOn && !menu.year && at >= 0
            x: grid.pad + at % 7 * grid.cw
            y: (Math.floor(at / 7) + 2) * grid.rh
            width: grid.cw
            height: grid.rh
            color: Theme.selBg
            Behavior on x {
                NumberAnimation {
                    duration: 90
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 90
                }
            }
        }

        Repeater {
            model: grid.dates
            delegate: Text {
                required property int index
                required property date modelData
                readonly property bool inMonth: modelData.getMonth() === grid.month
                readonly property bool isCursor: grid.cursorOn && !menu.year && menu.sameDay(modelData, menu.cursor)
                readonly property bool isToday: menu.sameDay(modelData, menu.today)

                x: grid.pad + index % 7 * grid.cw
                y: (Math.floor(index / 7) + 2) * grid.rh
                width: grid.cw
                height: grid.rh
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: inMonth || grid.weeks ? modelData.getDate() : ""
                color: isCursor ? Theme.sel : isToday && inMonth ? Theme.selBg : inMonth ? Theme.fg : Theme.line
                font.family: grid.font.family
                font.pointSize: grid.font.pointSize
                font.bold: isToday && inMonth

                MouseArea {
                    anchors.fill: parent
                    enabled: !menu.year
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.go(parent.modelData)
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Component.onCompleted: show([])
}
