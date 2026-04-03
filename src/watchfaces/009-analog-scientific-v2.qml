/*
 * Copyright (C) 2023 - Timo Könnecke <github.com/eLtMosen>
 *               2016 - Sylvia van Os <iamsylvie@openmailbox.org>
 *               2015 - Florent Revest <revestflo@gmail.com>
 *               2012 - Vasiliy Sorokin <sorokin.vasiliy@gmail.com>
 *                      Aleksey Mikhailichenko <a.v.mich@gmail.com>
 *                      Arto Jalkanen <ajalkane@gmail.com>
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import Nemo.Mce 1.0
import QtGraphicalEffects 1.15
import QtQuick 2.15
import QtQuick.Shapes 1.15
import org.asteroid.controls 1.0
import org.asteroid.utils 1.0

Item {
    property string imgPath: "../watchfaces-img/analog-scientific-v2-"
    property real rad: 0.01745

    anchors.fill: parent

    MceBatteryLevel {
        id: batteryChargePercentage
    }

    Item {
        id: root

        anchors.centerIn: parent
        height: parent.width > parent.height ? parent.height : parent.width
        width: height

        Item {
            id: dialBox

            anchors.fill: root
            layer.enabled: true
            layer.samples: 2

            Repeater {
                model: 60

                Rectangle {
                    id: minuteStrokes

                    property real rotM: (index - 15) / 60
                    property real centerX: root.width / 2 - width / 2
                    property real centerY: root.height / 2 - height / 2

                    x: index % 5 ? centerX + Math.cos(rotM * 2 * Math.PI) * parent.width * 0.488 : centerX + Math.cos(rotM * 2 * Math.PI) * parent.width * 0.48
                    y: index % 5 ? centerY + Math.sin(rotM * 2 * Math.PI) * parent.width * 0.488 : centerY + Math.sin(rotM * 2 * Math.PI) * parent.width * 0.48
                    antialiasing: true
                    color: index % 5 ? "#77ffffff" : "#ffffffff"
                    width: index % 5 ? parent.width * 0.0066 : parent.width * 0.009
                    height: index % 5 ? parent.height * 0.026 : parent.height * 0.038

                    transform: Rotation {
                        origin.x: width / 2
                        origin.y: height / 2
                        angle: (index) * 6
                    }

                }

            }

            Repeater {
                model: 12

                Text {
                    id: hourNumbers

                    property real rotM: ((index * 5) - 15) / 60
                    property real centerX: parent.width / 2 - width / 2
                    property real centerY: parent.height / 2 - height / 2

                    x: index === 10 ? centerX + Math.cos(rotM * 2 * Math.PI) * parent.width * 0.378 : index === 11 ? centerX + Math.cos(rotM * 2 * Math.PI) * parent.width * 0.388 : centerX + Math.cos(rotM * 2 * Math.PI) * parent.width * 0.4
                    y: index === 10 ? centerY + Math.sin(rotM * 2 * Math.PI) * parent.width * 0.378 : index === 11 ? centerY + Math.sin(rotM * 2 * Math.PI) * parent.width * 0.388 : centerY + Math.sin(rotM * 2 * Math.PI) * parent.width * 0.4
                    horizontalAlignment: Text.AlignHCenter
                    color: "#ffffffff"
                    text: index === 0 ? "12" : index

                    font {
                        pixelSize: parent.height * 0.088
                        family: "Outfit"
                        styleName: "Regular"
                    }

                }

            }

            Image {
                id: asteroidLogo

                visible: !displayAmbient
                source: "../watchfaces-img/asteroid-logo.svg"
                antialiasing: true
                width: parent.width * 0.12
                height: parent.height * 0.12
                opacity: 0.7

                anchors {
                    centerIn: parent
                    verticalCenterOffset: -parent.height * 0.272
                }

                Text {
                    id: asteroidSlogan

                    visible: !displayAmbient
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    text: "<b>AsteroidOS</b><br>Free Your Wrist"

                    anchors {
                        centerIn: parent
                        verticalCenterOffset: -parent.height * 0.005
                    }

                    font {
                        pixelSize: parent.height * 0.31
                        family: "Raleway"
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    onPressAndHold: asteroidLogo.visible ? asteroidLogo.visible = false : asteroidLogo.visible = true
                }

            }

            Text {
                id: digitalDisplay

                color: "#bbffffff"
                text: {
                    if (use12H.value)
                        wallClock.time.toLocaleString(Qt.locale(), "hh ap").slice(0, 2);
                    else
                        wallClock.time.toLocaleString(Qt.locale(), "HH");
                }

                anchors {
                    right: parent.horizontalCenter
                    rightMargin: parent.width * 0.004
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: -parent.width * 0.124
                }

                font {
                    pixelSize: parent.height * 0.15
                    family: "Open Sans"
                    styleName: "Regular"
                    letterSpacing: -parent.width * 0.001
                }

            }

            Text {
                id: digitalMinutes

                color: "#ccffffff"
                text: wallClock.time.toLocaleString(Qt.locale(), "mm")

                anchors {
                    left: digitalDisplay.right
                    bottom: digitalDisplay.bottom
                    leftMargin: root.width * 0.004
                }

                font {
                    pixelSize: root.height * 0.15
                    family: "Open Sans"
                    styleName: "Light"
                    letterSpacing: -parent.width * 0.001
                }

            }

            Text {
                id: apDisplay

                visible: use12H.value
                color: "#ddffffff"
                text: wallClock.time.toLocaleString(Qt.locale(), "ap").toUpperCase()

                anchors {
                    left: digitalMinutes.right
                    leftMargin: parent.width * 0.014
                    bottom: digitalMinutes.verticalCenter
                    bottomMargin: -parent.width * 0.012
                }

                font {
                    pixelSize: root.height * 0.06
                    family: "Open Sans Condensed"
                    styleName: "Regular"
                }

            }

            Item {
                id: dayBox

                property var day: wallClock.time.toLocaleString(Qt.locale(), "dd")

                onDayChanged: dayArc.requestPaint()
                width: parent.width * 0.22
                height: parent.height * 0.22

                anchors {
                    centerIn: parent
                    verticalCenterOffset: parent.width * 0.06
                    horizontalCenterOffset: -parent.width * 0.23
                }

                Canvas {
                    id: dayArc

                    anchors.fill: parent
                    opacity: !displayAmbient ? 1 : 0.3
                    smooth: true
                    renderStrategy: Canvas.Cooperative
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.beginPath();
                        ctx.fillStyle = "#22ffffff";
                        ctx.arc(parent.width / 2, parent.height / 2, parent.width * 0.45, 270 * rad, 360, false);
                        ctx.strokeStyle = "#77ffffff";
                        ctx.lineWidth = root.height * 0.002;
                        ctx.stroke();
                        ctx.fill();
                        ctx.closePath();
                        ctx.lineWidth = root.height * 0.005;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = "#ff98E2C6";
                        ctx.beginPath();
                        ctx.arc(parent.width / 2, parent.height / 2, parent.width * 0.456, 169 * rad, ((wallClock.time.getDay() / 7 * 360) + 169) * rad, false);
                        ctx.stroke();
                        ctx.closePath();
                    }
                }

                Repeater {
                    model: 7
                    visible: !displayAmbient

                    Text {
                        id: dayStrokes

                        property bool currentDayHighlight: new Date(2017, 1, index).toLocaleString(Qt.locale(), "ddd") === wallClock.time.toLocaleString(Qt.locale(), "ddd")
                        property real rotM: ((index * 8.7) - 15) / 60
                        property real centerX: parent.width / 2 - width / 2
                        property real centerY: parent.height / 2 - height / 2

                        x: centerX + Math.cos(rotM * 2 * Math.PI) * parent.width * 0.35
                        y: centerY + Math.sin(rotM * 2 * Math.PI) * parent.width * 0.35
                        antialiasing: true
                        opacity: !displayAmbient ? 1 : 0.6
                        color: currentDayHighlight ? "#ffffffff" : "#88ffffff"
                        text: new Date(2017, 1, index).toLocaleString(Qt.locale(), "ddd").slice(0, 2).toUpperCase()

                        font {
                            pixelSize: currentDayHighlight ? root.height * 0.036 : root.height * 0.03
                            letterSpacing: parent.width * 0.004
                            family: "Outfit"
                            styleName: currentDayHighlight ? "Bold" : "Regular"
                        }

                        transform: Rotation {
                            origin.x: width / 2
                            origin.y: height / 2
                            angle: index * 52
                        }

                    }

                }

                Text {
                    id: dayDisplay

                    color: "#ffffffff"
                    text: wallClock.time.toLocaleString(Qt.locale(), "dd").slice(0, 2).toUpperCase()

                    anchors {
                        centerIn: parent
                        verticalCenterOffset: -root.width * 0.003
                    }

                    font {
                        pixelSize: parent.height * 0.39
                        family: "Noto Sans"
                        styleName: "Condensed Light"
                    }

                }

            }

            Item {
                id: monthBox

                property var month: wallClock.time.toLocaleString(Qt.locale(), "mm")

                onMonthChanged: monthArc.requestPaint()
                width: parent.width * 0.22
                height: parent.height * 0.22

                anchors {
                    centerIn: parent
                    verticalCenterOffset: parent.width * 0.06
                    horizontalCenterOffset: parent.width * 0.23
                }

                Canvas {
                    id: monthArc

                    anchors.fill: parent
                    opacity: !displayAmbient ? 1 : 0.3
                    smooth: true
                    renderStrategy: Canvas.Cooperative
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.beginPath();
                        ctx.fillStyle = "#22ffffff";
                        ctx.arc(parent.width / 2, parent.height / 2, parent.width * 0.45, 270 * rad, 360, false);
                        ctx.strokeStyle = "#77ffffff";
                        ctx.lineWidth = root.height * 0.002;
                        ctx.stroke();
                        ctx.fill();
                        ctx.closePath();
                        ctx.lineWidth = root.height * 0.005;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = "#ff98E2C6";
                        ctx.beginPath();
                        ctx.arc(parent.width / 2, parent.height / 2, parent.width * 0.456, 270 * rad, ((wallClock.time.toLocaleString(Qt.locale(), "MM") / 12 * 360) + 270) * rad, false);
                        ctx.stroke();
                        ctx.closePath();
                    }
                }

                Repeater {
                    model: 12

                    Text {
                        id: monthStrokes

                        property bool currentMonthHighlight: Number(wallClock.time.toLocaleString(Qt.locale(), "MM")) === index || Number(wallClock.time.toLocaleString(Qt.locale(), "MM")) === index + 12
                        property real rotM: ((index * 5) - 15) / 60
                        property real centerX: parent.width / 2 - width / 2
                        property real centerY: parent.height / 2 - height / 2

                        x: centerX + Math.cos(rotM * 2 * Math.PI) * parent.width * 0.35
                        y: centerY + Math.sin(rotM * 2 * Math.PI) * parent.width * 0.35
                        antialiasing: true
                        opacity: !displayAmbient ? 1 : 0.6
                        color: currentMonthHighlight ? "#ffffffff" : "#88ffffff"
                        text: index === 0 ? 12 : index

                        font {
                            pixelSize: currentMonthHighlight ? root.height * 0.036 : root.height * 0.03
                            letterSpacing: parent.width * 0.004
                            family: "Outfit"
                            styleName: currentMonthHighlight ? "Bold" : "Regular"
                        }

                        transform: Rotation {
                            origin.x: width / 2
                            origin.y: height / 2
                            angle: (index * 30)
                        }

                    }

                }

                Text {
                    id: monthDisplay

                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    color: "#ddffffff"
                    text: wallClock.time.toLocaleString(Qt.locale(), "MMM").slice(0, 3).toUpperCase()

                    font {
                        pixelSize: parent.height * 0.366
                        family: "Noto Sans"
                        styleName: "Condensed Light"
                        letterSpacing: -root.width * 0.0018
                    }

                }

            }

            Item {
                id: batteryBox

                property int value: batteryChargePercentage.percent

                onValueChanged: batteryArc.requestPaint()
                width: parent.width * 0.26
                height: parent.height * 0.26

                anchors {
                    centerIn: parent
                    verticalCenterOffset: parent.width * 0.206
                }

                Canvas {
                    id: batteryArc

                    property int hour: 0

                    opacity: !displayAmbient ? 1 : 0.3
                    anchors.fill: parent
                    smooth: true
                    renderStrategy: Canvas.Cooperative
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.beginPath();
                        ctx.fillStyle = "#22ffffff";
                        ctx.arc(parent.width / 2, parent.height / 2, parent.width * 0.45, 270 * rad, 360, false);
                        ctx.strokeStyle = "#77ffffff";
                        ctx.lineWidth = root.height * 0.002;
                        ctx.stroke();
                        ctx.fill();
                        ctx.closePath();
                        var gradient = ctx.createRadialGradient(parent.width / 2, parent.height / 2, 0, parent.width / 2, parent.height / 2, parent.width * 0.46);
                        gradient.addColorStop(0.44, batteryChargePercentage.percent < 30 ? "#00EF476F" : batteryChargePercentage.percent < 60 ? "#00D0E562" : "#0023F0C7");
                        gradient.addColorStop(0.97, batteryChargePercentage.percent < 30 ? "#ffEF476F" : batteryChargePercentage.percent < 60 ? "#ffD0E562" : "#ff23F0C7");
                        ctx.lineWidth = root.height * 0.005;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = gradient;
                        ctx.beginPath();
                        ctx.arc(parent.width / 2, parent.height / 2, parent.width * 0.456, 270 * rad, ((batteryChargePercentage.percent / 100 * 360) + 270) * rad, false);
                        ctx.lineTo(parent.width / 2, parent.height / 2);
                        ctx.stroke();
                        ctx.closePath();
                    }
                }

                Text {
                    id: batteryDisplay

                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    color: "#ffffffff"
                    text: batteryChargePercentage.percent

                    font {
                        pixelSize: parent.height * (batteryDisplay.text === "100" ? 0.46 : 0.48)
                        family: "Outfit"
                        styleName: "Thin"
                    }

                    Text {
                        id: batteryPercent

                        renderType: Text.NativeRendering
                        horizontalAlignment: Text.AlignHCenter
                        lineHeightMode: Text.FixedHeight
                        lineHeight: parent.height * 0.94
                        color: !displayAmbient ? "#bbffffff" : "#55ffffff"
                        text: "BAT<br>%"

                        anchors {
                            centerIn: batteryDisplay
                            verticalCenterOffset: parent.height * 0.34
                        }

                        font {
                            pixelSize: parent.height * 0.194
                            family: "Open Sans"
                            styleName: "Regular"
                        }

                    }

                }

            }

            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 2
                verticalOffset: 2
                radius: 5
                samples: 11
                color: "#99000000"
            }

        }

        Item {
            id: handBox

            anchors.fill: root

            Image {
                id: hourSVG

                anchors.centerIn: handBox
                source: imgPath + (displayAmbient ? "hour-bw.svg" : "hour.svg")
                antialiasing: true
                width: handBox.width
                height: handBox.height

                layer {
                    enabled: true
                    samples: 2
                    textureSize: Qt.size(root.width * 2, root.height * 2)

                    effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 4
                        verticalOffset: 4
                        radius: 7
                        samples: 15
                        color: Qt.rgba(0, 0, 0, 0.2)
                    }

                }

                transform: Rotation {
                    origin.x: handBox.width / 2
                    origin.y: handBox.height / 2
                    angle: hourSVG.toggle24h ? (wallClock.time.getHours() * 15) + (wallClock.time.getMinutes() * 0.25) : (wallClock.time.getHours() * 30) + (wallClock.time.getMinutes() * 0.5)

                    Behavior on angle {
                        RotationAnimation {
                            duration: 500
                            direction: RotationAnimation.Clockwise
                            easing.type: Easing.InOutQuad
                        }

                    }

                }

            }

            Image {
                id: minuteSVG

                anchors.centerIn: handBox
                source: imgPath + (displayAmbient ? "minute-bw.svg" : "minute.svg")
                antialiasing: true
                width: handBox.width
                height: handBox.height

                layer {
                    enabled: true
                    samples: 2
                    textureSize: Qt.size(root.width * 2, root.height * 2)

                    effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 5
                        verticalOffset: 5
                        radius: 9
                        samples: 19
                        color: Qt.rgba(0, 0, 0, 0.2)
                    }

                }

                transform: Rotation {
                    origin.x: handBox.width / 2
                    origin.y: handBox.height / 2
                    angle: (wallClock.time.getMinutes() * 6) + (wallClock.time.getSeconds() * 6 / 60)

                    Behavior on angle {
                        RotationAnimation {
                            duration: 1000
                            direction: RotationAnimation.Clockwise
                        }

                    }

                }

            }

            Image {
                id: secondSVG

                anchors.centerIn: handBox
                source: imgPath + "second.svg"
                antialiasing: true
                visible: !displayAmbient
                width: handBox.width
                height: handBox.height

                layer {
                    enabled: true
                    samples: 2
                    textureSize: Qt.size(root.width * 2, root.height * 2)

                    effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 7
                        verticalOffset: 7
                        radius: 10
                        samples: 21
                        color: Qt.rgba(0, 0, 0, 0.2)
                    }

                }

                transform: Rotation {
                    origin.x: handBox.width / 2
                    origin.y: handBox.height / 2
                    angle: (wallClock.time.getSeconds() * 6)
                }

            }

        }

        Item {
            id: nightstandMode

            readonly property bool active: nightstand

            anchors.fill: parent
            visible: nightstandMode.active

            layer {
                enabled: true
                samples: 4
                smooth: true
                textureSize: Qt.size(nightstandMode.width * 2, nightstandMode.height * 2)
            }

            Repeater {
                id: segmentedArc

                property real inputValue: batteryChargePercentage.percent / 100
                property int segmentAmount: 60
                property int start: -10
                property int gap: 4
                property int endFromStart: 360
                property bool clockwise: true
                property real arcStrokeWidth: 0.016
                property real scalefactor: 0.5 - (arcStrokeWidth / 2)
                property real chargecolor: Math.floor(batteryChargePercentage.percent / 33.35)
                readonly property var colorArray: ["red", "yellow", Qt.rgba(0.318, 1, 0.051, 0.9)]

                model: segmentAmount

                Shape {
                    id: segment

                    visible: index === 0 ? true : (index / segmentedArc.segmentAmount) < segmentedArc.inputValue

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: segmentedArc.colorArray[segmentedArc.chargecolor]
                        strokeWidth: parent.height * segmentedArc.arcStrokeWidth
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.MiterJoin
                        startX: parent.width / 2
                        startY: parent.height * (0.5 - segmentedArc.scalefactor)

                        PathAngleArc {
                            centerX: parent.width / 2
                            centerY: parent.height / 2
                            radiusX: segmentedArc.scalefactor * parent.width
                            radiusY: segmentedArc.scalefactor * parent.height
                            startAngle: -90 + index * (sweepAngle + (segmentedArc.clockwise ? +segmentedArc.gap : -segmentedArc.gap)) + segmentedArc.start
                            sweepAngle: segmentedArc.clockwise ? (segmentedArc.endFromStart / segmentedArc.segmentAmount) - segmentedArc.gap : -(segmentedArc.endFromStart / segmentedArc.segmentAmount) + segmentedArc.gap
                            moveToStart: true
                        }

                    }

                }

            }

        }

    }

}
