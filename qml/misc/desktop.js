.pragma library
var panelsGrid
var appLauncher

function onAboutToClose() {
    panelsGrid.moveTo(0, 0);
    appLauncher.positionViewAtBeginning();
}
function onAboutToMinimize() { panelsGrid.moveTo(0, 1) }
