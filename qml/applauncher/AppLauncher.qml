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
import org.nemomobile.lipstick 0.1
import Nemo.Configuration 1.0

ListView {
    id: appsListView
    orientation: ListView.Horizontal
    snapMode: ListView.SnapToItem

    property bool fakePressed:     false
    property bool toTopAllowed:    false
    property bool toBottomAllowed: false
    property bool toLeftAllowed:   true
    property bool toRightAllowed:  false
    property int currentPos: 0
    property int savedPos: 0

    ConfigurationValue {
        id: itemIndex
        key: "/launcher/item-index"
        defaultValue: 0
    }

    onCurrentPosChanged: {
        toLeftAllowed = (currentPos!=launcherModel.itemCount-1)
        toRightAllowed  = (currentPos!=0)

        // Save item index in case the launcher gets killed.
        itemIndex.value = currentPos

        rightIndicator.animate()
        leftIndicator.animate()
        topIndicator.animate()
        bottomIndicator.animate()
    }

    model: LauncherModel { id: launcherModel }

    delegate: LauncherItemDelegate {
        id: launcherItem
        // In onCompleted the width of appsListView is zero, we need it to be non-zero
        // in order to make positionViewAtIndex work
        width: appsListView.width == 0 ? 1 : appsListView.width
        height: appsListView.width
        iconName: model.object.iconId == "" ? "ios-help" : model.object.iconId
        iconCaption: model.object.title.toUpperCase() + localeManager.changesObserver
        enabled: !appsListView.dragging
    }

    Component.onCompleted: {
        currentPos = itemIndex.value
        savedPos = currentPos
        launcherCenterColor = alb.centerColor(launcherModel.get(savedPos).filePath);
        launcherOuterColor = alb.outerColor(launcherModel.get(savedPos).filePath);
        // When moving the view to a different index we get that savedPos becomes 0,0.
        // This means that when we flick left the contentX becomes negative.
        // This results in the first iitem being index -savedPos.
        // To fix this we add savedPos to make the first item at index zero.
        positionViewAtIndex(savedPos, ListView.Visible)
    }

    onContentXChanged: {
        var lowerStop = Math.floor(contentX/appsListView.width) + savedPos
        var upperStop = lowerStop+1
        var ratio = ((contentX + savedPos*appsListView.width)%appsListView.width)/appsListView.width

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
