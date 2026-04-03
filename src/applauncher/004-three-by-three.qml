/*
 * Copyright (C) 2023 Ed Beroset <beroset@ieee.org>
 *               2022 Timo Könnecke <github.com/eLtMosen>
 *               2021 Darrel Griët <dgriet@gmail.com>
 *               2015 Florent Revest <revestflo@gmail.com>
 *               2014 Aleksi Suomalainen <suomalainen.aleksi@gmail.com>
 *               2012 Timur Kristóf <venemo@fedoraproject.org>
 *               2011 Tom Swindell <t.swindell@rubyx.co.uk>
 * All rights reserved.
 *
 * You may use this file under the terms of BSD license as follows:
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the author nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import QtGraphicalEffects 1.12
import QtQuick 2.15
import org.asteroid.controls 1.0
import org.asteroid.utils 1.0

Item {
    // these are from the calling code
    /*
    property bool fakePressed:     false
    property bool toTopAllowed:    true
    property bool toBottomAllowed: true
    property bool toLeftAllowed:   true
    property bool toRightAllowed:  true
    property bool forbidTop:       false
    property bool forbidBottom:    false
    property bool forbidLeft:      false
    property bool forbidRight:     false
    */

    id: root

    property int currentPressedIndex: 0
    property bool clickToggle: false
    property bool pressToggle: false
    property bool dragStop: false
    property string appTitle: ""
    property real clickY: 0
    property int numColumns: 3

    Connections {
        function onCurrentVerticalPosChanged() {
            // Move app view to beginning when the watchface is visible.
            if (grid.currentVerticalPos === 0)
                appsView.positionViewAtBeginning();

        }

        target: grid
    }

    Component {
        id: gridDelegate

        MouseArea {
            id: launcherItem

            property int pressAndHoldDuration: 200

            signal timedPressAndHold()

            width: appsView.width / numColumns
            height: width
            enabled: !appsView.dragging
            onClicked: {
                clickToggle = true;
                model.object.launchApplication();
            }
            onPressed: {
                pressAndHoldTimer.start();
                root.dragStop = false;
            }
            onReleased: {
                pressAndHoldTimer.stop();
            }
            onTimedPressAndHold: {
                appTitle = model.object.title;
                clickToggle = false;
                pressToggle ? pressToggle = false : pressToggle = true;
                currentPressedIndex = index;
            }

            Timer {
                id: pressAndHoldTimer

                interval: parent.pressAndHoldDuration
                running: false
                repeat: false
                onTriggered: {
                    if (!root.dragStop)
                        parent.timedPressAndHold();
                    else
                        root.dragStop = false;
                }
            }

            Connections {
                function onFakePressedChanged() {
                    appTitle = model.object.title;
                }

                target: appLauncher
            }

            Item {
                id: circleWrapper

                width: parent.width * 0.86
                height: width

                anchors {
                    centerIn: parent
                }

                Rectangle {
                    id: circle

                    anchors.fill: parent
                    radius: width / 2
                    color: !pressAndHoldTimer.running && launcherItem.pressed | fakePressed ? alb.centerColor(launcherModel.get(currentPressedIndex).filePath) : "#f4f4f4"

                    Behavior on color {
                        PropertyAnimation {
                            target: circle
                            property: "color"
                            duration: 70
                        }

                    }

                }

            }

            DropShadow {
                anchors.fill: circleWrapper
                horizontalOffset: 0
                verticalOffset: 0
                radius: 8
                samples: 17
                color: "#80000000"
                source: circleWrapper
                cached: true
            }

            Icon {
                id: icon

                width: circleWrapper.width * 0.7
                height: width
                anchors.centerIn: circleWrapper
                color: !pressAndHoldTimer.running && launcherItem.pressed | fakePressed ? "#fff" : "#555"
                name: model.object.iconId === "" ? "ios-help" : model.object.iconId

                Behavior on color {
                    PropertyAnimation {
                        target: icon
                        property: "color"
                        duration: 70
                    }

                }

            }

        }

    }

    Component {
        id: spacer

        Item {
            height: DeviceSpecs.hasRoundScreen ? root.height / numColumns / 2 : 0
            width: height
        }

    }

    GridView {
        id: appsView

        property int currentPos: 0

        flow: GridView.FlowLeftToRight
        snapMode: GridView.SnapToRow
        clip: true
        cellHeight: height / numColumns
        cellWidth: width / numColumns
        contentY: -height / (2 * numColumns)
        header: spacer
        footer: spacer
        onCurrentPosChanged: {
            rightIndicator.animate();
            leftIndicator.animate();
            topIndicator.animate();
            bottomIndicator.animate();
        }
        onDragStarted: {
            dragStop = true;
        }
        onAtYBeginningChanged: {
            // Make sure that the grid doesn't move when the app view is visible.
            if ((grid.currentHorizontalPos === 0) && (grid.currentVerticalPos === 1)) {
                forbidTop = !atYBeginning;
                grid.changeAllowedDirections();
            }
        }
        model: launcherModel
        delegate: gridDelegate
        Component.onCompleted: {
            launcherColorOverride = true;
            toLeftAllowed = false;
            toRightAllowed = false;
            toBottomAllowed = Qt.binding(function() {
                return !atYBeginning;
            });
            toTopAllowed = Qt.binding(function() {
                return !atYEnd;
            });
            forbidTop = Qt.binding(function() {
                return !atYBeginning;
            });
            forbidBottom = false;
            forbidLeft = false;
            forbidRight = false;
        }

        anchors {
            fill: parent
            leftMargin: parent.width * 0.026
            rightMargin: parent.width * 0.026
        }

        Connections {
            function onCurrentVerticalPosChanged() {
                // Move app view to beginning when the watchface is visible.
                if (grid.currentVerticalPos === 0) {
                    appsView.highlightMoveDuration = 0;
                    appsView.currentIndex = 0;
                    dragStop = true;
                } else if (grid.currentVerticalPos === 1) {
                    appsView.highlightMoveDuration = 1500;
                    forbidTop = false;
                    grid.changeAllowedDirections();
                }
            }

            target: grid
        }

    }

    MouseArea {
        id: absoluteMouse

        anchors.fill: parent
        propagateComposedEvents: true
        onPressed: {
            clickY = Math.round(mouse.y);
            mouse.accepted = false;
        }
        onClicked: mouse.accepted = false
        onReleased: mouse.accepted = false
        onDoubleClicked: mouse.accepted = false
        onPositionChanged: mouse.accepted = false
        onPressAndHold: mouse.accepted = false
    }

    Rectangle {
        id: titleShutter

        opacity: 0
        visible: !root.clickToggle
        width: root.width
        height: root.height * 0.24
        color: alb.centerColor(launcherModel.get(currentPressedIndex).filePath)

        anchors {
            centerIn: hoverTitle
            verticalCenterOffset: root.clickY > Dims.h(48) ? -Dims.h(2) : Dims.h(2)
        }

    }

    Text {
        id: hoverTitle

        // Offset hoverText and shutter out of view, either to top or bottom depending on vertical click position
        property real hoverTextOffset: root.clickY > Dims.h(48) ? -Dims.h(62) : Dims.h(62)
        property bool rootPressToggle: root.pressToggle

        width: parent.width
        color: "#fff"
        opacity: 0
        visible: !root.clickToggle
        horizontalAlignment: Text.AlignHCenter
        anchors.centerIn: parent
        style: Text.Outline
        styleColor: alb.centerColor(launcherModel.get(currentPressedIndex).filePath)
        text: appTitle.toUpperCase() + localeManager.changesObserver
        layer.enabled: true

        font {
            pixelSize: ((appsView.width > appsView.height ? appsView.height : appsView.width) / Dims.l(100)) * Dims.l(9)
            styleName: "Condensed Medium"
            letterSpacing: -parent.width * 0.004
        }

        Behavior on rootPressToggle {
            SequentialAnimation {
                id: fadeText

                // Reset position of all animated items for the case an animation has been interrupted
                NumberAnimation {
                    target: hoverTitle
                    property: "anchors.verticalCenterOffset"
                    to: hoverTitle.hoverTextOffset
                    duration: 0
                }

                NumberAnimation {
                    target: hoverTitle
                    property: "opacity"
                    to: 1
                    duration: 0
                }

                NumberAnimation {
                    target: titleShutter
                    property: "opacity"
                    to: 0.85
                    duration: 0
                }

                PropertyAction {
                }

                // Slide in hoverTitle and shutter to either negative or positve offset from center depending on vertical click position
                NumberAnimation {
                    target: hoverTitle
                    property: "anchors.verticalCenterOffset"
                    to: -hoverTitle.hoverTextOffset + (hoverTitle.hoverTextOffset * 1.58)
                    duration: 100
                    easing.type: Easing.InSine
                }

                // Keep hoverTitle in visible position for 1s
                PauseAnimation {
                    duration: 1000
                }

                // Slide hoverTitle and shutter out of view again
                ParallelAnimation {
                    NumberAnimation {
                        target: hoverTitle
                        property: "opacity"
                        to: 0
                        duration: 200
                        easing.type: Easing.InSine
                    }

                    NumberAnimation {
                        target: titleShutter
                        property: "opacity"
                        to: 0
                        duration: 200
                        easing.type: Easing.InSine
                    }

                    NumberAnimation {
                        target: hoverTitle
                        property: "anchors.verticalCenterOffset"
                        to: hoverTitle.hoverTextOffset
                        duration: 200
                        easing.type: Easing.InSine
                    }

                }

            }

        }

        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 0
            verticalOffset: 0
            radius: 2
            samples: 5
            color: "#88000000"
        }

    }

}
