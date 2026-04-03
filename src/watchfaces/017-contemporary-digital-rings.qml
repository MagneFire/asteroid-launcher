/*
 * Copyright (C) 2023 - Timo Könnecke <github.com/eLtMosen>
 *               2022 - Darrel Griët <dgriet@gmail.com>
 *               2022 - Ed Beroset <github.com/beroset>
 *               2017 - Mario Kicherer <dev@kicherer.org>
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
/*
 * Based on analog-precison by Mario Kicherer. Remodeled the arms to arcs
 * and tried hard on font centering and anchor alignment.
 */

import Nemo.Mce 1.0
import QtGraphicalEffects 1.15
import QtQuick 2.15
import QtQuick.Shapes 1.15
import org.asteroid.controls 1.0
import org.asteroid.utils 1.0

Item {
    property real radian: 0.01745

    function prepareContext(ctx) {
        ctx.reset();
        ctx.shadowColor = (0, 0, 0, 0.25);
        ctx.shadowOffsetX = 0;
        ctx.shadowOffsetY = 0;
        ctx.shadowBlur = parent.height * 0.00625;
        ctx.lineCap = "round";
    }

    anchors.fill: parent

    Item {
        anchors.centerIn: parent
        height: parent.width > parent.height ? parent.height : parent.width
        width: height
        Component.onCompleted: {
            var hour = wallClock.time.getHours();
            var minute = wallClock.time.getMinutes();
            var second = wallClock.time.getSeconds();
            secondCanvas.second = second;
            secondCanvas.requestPaint();
            minuteCanvas.minute = minute;
            minuteCanvas.requestPaint();
            hourCanvas.hour = hour;
            hourCanvas.requestPaint();
            burnInProtectionManager.widthOffset = Qt.binding(function() {
                return width * nightstandMode.active ? 0.08 : 0.3;
            });
            burnInProtectionManager.heightOffset = Qt.binding(function() {
                return height * nightstandMode.active ? 0.08 : 0.3;
            });
        }

        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - width / 2
            color: Qt.rgba(0, 0, 0, 0.2)
            width: parent.width / 1.3
            height: parent.height / 1.3
            radius: width * 0.5
        }

        Canvas {
            id: secondCanvas

            property int second: 0

            anchors.fill: parent
            smooth: true
            renderStrategy: Canvas.Cooperative
            visible: !displayAmbient && !nightstandMode.active
            onPaint: {
                var ctx = getContext("2d");
                var rot = (wallClock.time.getSeconds() - 15) * 6;
                var rot_half = (wallClock.time.getSeconds() - 22) * 6;
                prepareContext(ctx);
                ctx.beginPath();
                ctx.arc(parent.width / 2, parent.height / 2, width / 2.2, -89.5 * radian, rot * radian, false);
                ctx.lineWidth = parent.width * 0.009375;
                ctx.strokeStyle = Qt.rgba(0.871, 0.165, 0.102, 0.95);
                ctx.stroke();
            }
        }

        Canvas {
            id: minuteCanvas

            property int minute: 0

            anchors.fill: parent
            smooth: true
            renderStrategy: Canvas.Cooperative
            visible: !displayAmbient && !nightstandMode.active
            onPaint: {
                var ctx = getContext("2d");
                var rot = (minute - 15) * 6;
                prepareContext(ctx);
                ctx.beginPath();
                ctx.arc(parent.width / 2, parent.height / 2, width / 2.33, -88.8 * radian, rot * radian, false);
                ctx.lineWidth = parent.width * 0.01875;
                ctx.strokeStyle = Qt.rgba(1, 0.549, 0.149, 0.95);
                ctx.stroke();
            }
        }

        Canvas {
            id: hourCanvas

            property int hour: 0

            anchors.fill: parent
            smooth: true
            renderStrategy: Canvas.Cooperative
            visible: !displayAmbient && !nightstandMode.active
            onPaint: {
                var ctx = getContext("2d");
                var rot = 0.5 * (60 * (hour - 3) + wallClock.time.getMinutes());
                prepareContext(ctx);
                ctx.beginPath();
                ctx.arc(parent.width / 2, parent.height / 2, width / 2.6, 273.5 * radian, rot * radian, false);
                ctx.lineWidth = parent.width * 0.05;
                ctx.strokeStyle = Qt.rgba(0.945, 0.769, 0.059, 0.95);
                ctx.stroke();
                ctx.beginPath();
            }
        }

        Text {
            id: hourDisplay

            color: Qt.rgba(1, 1, 1, 1)
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
            text: {
                if (use12H.value)
                    wallClock.time.toLocaleString(Qt.locale(), "hh ap").slice(0, 2);
                else
                    wallClock.time.toLocaleString(Qt.locale(), "HH");
            }

            anchors {
                right: parent.horizontalCenter
                rightMargin: -parent.height * 0.0938
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: parent.height * 0.0281
            }

            font {
                pixelSize: parent.height * 0.375
                family: "Titillium"
                styleName: 'Bold'
                letterSpacing: -3
            }

        }

        Text {
            id: minuteDisplay

            property real rotM: (wallClock.time.getMinutes() - 12.1) / 60

            color: Qt.rgba(1, 1, 1, 1)
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
            text: wallClock.time.toLocaleString(Qt.locale(), "mm")

            anchors {
                top: hourDisplay.top
                topMargin: -parent.height * 0.015625
                leftMargin: parent.width * 0.025
                left: hourDisplay.right
            }

            font {
                pixelSize: parent.height * 0.1375
                styleName: 'Semibold'
                letterSpacing: -1
            }

        }

        Text {
            id: secondDisplay

            color: Qt.rgba(1, 1, 1, 1)
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
            horizontalAlignment: Text.AlignHCenter
            text: wallClock.time.toLocaleString(Qt.locale(), "ss")
            visible: !displayAmbient

            anchors {
                bottom: hourDisplay.bottom
                bottomMargin: parent.height * 0.059375
                leftMargin: parent.width * 0.025
                left: hourDisplay.right
            }

            font {
                pixelSize: parent.height * 0.1375
                family: "Titillium"
                styleName: 'Thin'
                letterSpacing: -1
            }

        }

        Text {
            id: dowDisplay

            color: Qt.rgba(1, 1, 1, 1)
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
            horizontalAlignment: Text.AlignHCenter
            text: wallClock.time.toLocaleString(Qt.locale(), "dddd")

            anchors {
                bottom: hourDisplay.top
                left: parent.left
                right: parent.right
            }

            font {
                pixelSize: parent.height * 0.084375
                family: "Titillium"
                styleName: 'Thin'
            }

        }

        Text {
            id: dateDisplay

            color: Qt.rgba(1, 1, 1, 1)
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
            horizontalAlignment: Text.AlignHCenter
            text: wallClock.time.toLocaleString(Qt.locale(), "<b>dd</b> MMMM")

            anchors {
                topMargin: -parent.height * 0.05
                top: hourDisplay.bottom
                left: parent.left
                right: parent.right
            }

            font {
                pixelSize: parent.height * 0.084375
                family: "Titillium"
                styleName: 'Thin'
            }

        }

        Text {
            id: pmDisplay

            color: Qt.rgba(1, 1, 1, 1)
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
            horizontalAlignment: Text.AlignHCenter
            visible: use12H.value
            text: wallClock.time.toLocaleString(Qt.locale(), "<b>ap</b>")

            anchors {
                bottomMargin: +parent.height * 0.018
                bottom: dowDisplay.top
                left: parent.left
                right: parent.right
            }

            font {
                pixelSize: parent.height * 0.05
                family: "Titillium"
                styleName: 'Semibold'
            }

        }

        Item {
            id: nightstandMode

            readonly property bool active: nightstand
            property int batteryPercentChanged: batteryChargePercentage.percent

            anchors.fill: parent
            visible: nightstandMode.active

            layer {
                enabled: true
                samples: 4
                smooth: true
                textureSize: Qt.size(nightstandMode.width * 2, nightstandMode.height * 2)
            }

            Shape {
                id: chargeArc

                property real angle: batteryChargePercentage.percent * 360 / 100
                // radius of arc is scalefactor * height or width
                property real arcStrokeWidth: 0.03
                property real scalefactor: 0.45 - (arcStrokeWidth / 2)
                property var chargecolor: Math.floor(batteryChargePercentage.percent / 33.35)
                readonly property var colorArray: ["red", "yellow", Qt.rgba(0.318, 1, 0.051, 0.9)]

                anchors.fill: parent
                smooth: true
                antialiasing: true

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: chargeArc.colorArray[chargeArc.chargecolor]
                    strokeWidth: parent.height * chargeArc.arcStrokeWidth
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.MiterJoin
                    startX: chargeArc.width / 2
                    startY: chargeArc.height * (0.5 - chargeArc.scalefactor)

                    PathAngleArc {
                        centerX: chargeArc.width / 2
                        centerY: chargeArc.height / 2
                        radiusX: chargeArc.scalefactor * chargeArc.width
                        radiusY: chargeArc.scalefactor * chargeArc.height
                        startAngle: -90
                        sweepAngle: chargeArc.angle
                        moveToStart: false
                    }

                }

            }

            Icon {
                id: batteryIcon

                name: "ios-battery-charging"
                visible: nightstandMode.active
                width: parent.width * 0.14
                height: parent.height * 0.14

                anchors {
                    centerIn: parent
                    verticalCenterOffset: -parent.width * 0.316
                }

            }

            ColorOverlay {
                anchors.fill: batteryIcon
                source: batteryIcon
                color: chargeArc.colorArray[chargeArc.chargecolor]
            }

            Text {
                id: batteryPercent

                visible: nightstandMode.active
                color: chargeArc.colorArray[chargeArc.chargecolor]
                style: Text.Outline
                styleColor: "#80000000"
                text: batteryChargePercentage.percent + "%"

                anchors {
                    centerIn: parent
                    verticalCenterOffset: parent.width * 0.324
                }

                font {
                    pixelSize: parent.width * 0.09
                    family: "Titillium"
                    styleName: "ExtraCondensed"
                }

            }

        }

        MceBatteryLevel {
            id: batteryChargePercentage
        }

        Connections {
            function onTimeChanged() {
                if (displayAmbient)
                    return ;

                var hour = wallClock.time.getHours();
                var minute = wallClock.time.getMinutes();
                var second = wallClock.time.getSeconds();
                if (secondCanvas.second !== second) {
                    secondCanvas.second = second;
                    secondCanvas.requestPaint();
                }
                if (hourCanvas.hour !== hour)
                    hourCanvas.hour = hour;

                if (minuteCanvas.minute !== minute) {
                    minuteCanvas.minute = minute;
                    minuteCanvas.requestPaint();
                    hourCanvas.requestPaint();
                }
            }

            target: wallClock
        }

    }

}
