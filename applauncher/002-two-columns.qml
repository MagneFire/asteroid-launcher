/*
 * Copyright (C) 2015 Florent Revest <revestflo@gmail.com>
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

import QtQuick 2.9
import org.asteroid.controls 1.0

GridView {
    id: appsView
    flow: GridView.FlowLeftToRight
    snapMode: GridView.SnapToRow
    anchors.fill: parent
    clip: true
    cellHeight: appsView.height/2
    highlightMoveDuration: 1500
    cellWidth: appsView.width/2

    preferredHighlightBegin: width /2 - currentItem.width /2
    preferredHighlightEnd: width /2 + currentItem.width /2
    highlightRangeMode: ListView.StrictlyEnforceRange
    contentY: -(width / 2 - (width / 4))

    property int currentPos: 0
    onAtYBeginningChanged: {
        if ((grid.currentHorizontalPos == 0) && (grid.currentVerticalPos == 1)) {
            forbidTop = !atYBeginning;
            grid.changeAllowedDirections()
        }
    }

    onCurrentPosChanged: {
        rightIndicator.animate()
        leftIndicator.animate()
        topIndicator.animate()
        bottomIndicator.animate()
    }

    model: launcherModel

    delegate: MouseArea {
        id: launcherItem
        width: appsView.width / 2
        height: appsView.width / 2
        enabled: !appsView.dragging

        onClicked: model.object.launchApplication()

        Image {
            anchors.fill: parent
            source: launcherItem.pressed | fakePressed ? "../applauncher-img/diskBackgroundPressed.svg" : "../applauncher-img/diskBackground.svg"
            sourceSize.width: width
            sourceSize.height: height
            y: -Dims.h(1)
        }

        Icon {
            id: icon
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Dims.h(1)
            width: parent.width * 0.6
            height: width
            color: "#666666"
            name: model.object.iconId == "" ? "ios-help" : model.object.iconId
        }

        Label {
            id: iconText
            anchors.top: icon.bottom
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            anchors.topMargin: Dims.h(3)
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ffffff"
            font.pixelSize: ((appsView.width > appsView.height ? appsView.height : appsView.width) / Dims.l(100)) * Dims.l(5)
            font.weight: Font.Medium
            text: model.object.title.toUpperCase() + localeManager.changesObserver
        }
    }

    Component.onCompleted: {
        launcherCenterColor = alb.centerColor(launcherModel.get(0).filePath);
        launcherOuterColor = alb.outerColor(launcherModel.get(0).filePath);

        toLeftAllowed = false
        toRightAllowed = false
        //toTopAllowed =  Qt.binding(function() { return !atXEnd })
        //toBottomAllowed = Qt.binding(function() { return !atXEnd })
        //toLeftAllowed = Qt.binding(function() { return !atXEnd })
        //toRightAllowed = Qt.binding(function() { return !atXBeginning })
        //forbidTop = Qt.binding(function() { return !atYBeginning })
        toTopAllowed = Qt.binding(function() { return !atYEnd })
    }

    onContentYChanged: {
        var lowerStop = Math.floor(contentY/appsView.height)
        var upperStop = lowerStop+1
        var ratio = (contentY%appsView.height)/appsView.height

        if(upperStop + 1 > launcherModel.itemCount || ratio == 0) {
            launcherCenterColor = alb.centerColor(launcherModel.get(lowerStop).filePath);
            launcherOuterColor = alb.outerColor(launcherModel.get(lowerStop).filePath);
            return;
        }

        if(lowerStop < 0) {
            launcherCenterColor = alb.centerColor(launcherModel.get(0).filePath);
            launcherOuterColor = alb.outerColor(launcherModel.get(0).filePath);
            return;
        }

        var upperCenterColor = alb.centerColor(launcherModel.get(upperStop).filePath);
        var lowerCenterColor = alb.centerColor(launcherModel.get(lowerStop).filePath);

        launcherCenterColor = Qt.rgba(
                    upperCenterColor.r * ratio + lowerCenterColor.r * (1-ratio),
                    upperCenterColor.g * ratio + lowerCenterColor.g * (1-ratio),
                    upperCenterColor.b * ratio + lowerCenterColor.b * (1-ratio)
                );

        var upperOuterColor = alb.outerColor(launcherModel.get(upperStop).filePath);
        var lowerOuterColor = alb.outerColor(launcherModel.get(lowerStop).filePath);

        launcherOuterColor = Qt.rgba(
                    upperOuterColor.r * ratio + lowerOuterColor.r * (1-ratio),
                    upperOuterColor.g * ratio + lowerOuterColor.g * (1-ratio),
                    upperOuterColor.b * ratio + lowerOuterColor.b * (1-ratio)
                );

        currentPos = Math.round(lowerStop+ratio)
    }
}
