function StatusBar() { }

StatusBar.prototype.isVisible = true;

StatusBar.prototype.isReady = function (callback) {
    cordova.exec(function (visible) {
        StatusBar.isVisible = visible;
        if (callback) callback(visible);
    }, null, 'StatusBar', '_ready', []);
};

StatusBar.prototype.styleDefault = function () {
    cordova.exec(null, null, 'StatusBar', 'styleDefault', []);
};

StatusBar.prototype.styleLightContent = function () {
    cordova.exec(null, null, 'StatusBar', 'styleLightContent', []);
};

StatusBar.prototype.overlaysWebView = function (doOverlay) {
    cordova.exec(null, null, 'StatusBar', 'overlaysWebView', [doOverlay]);
};

StatusBar.prototype.backgroundColorByName = function (colorname) {
    var hex = namedColors[colorname] || '#FFFFFF';
    return StatusBar.backgroundColorByHexString(hex);
};

StatusBar.prototype.backgroundColorByHexString = function (hexString) {
    if (typeof hexString !== 'string') return;
    if (hexString.charAt(0) !== '#') {
        hexString = '#' + hexString;
    }
    if (hexString.length === 4) {
        var split = hexString.split('');
        hexString = '#' + split[1] + split[1] + split[2] + split[2] + split[3] + split[3];
    }
    cordova.exec(null, null, 'StatusBar', 'backgroundColorByHexString', [hexString]);
};

StatusBar.prototype.navigationBackgroundColorByHexString = function (hexString) {
    if (typeof hexString !== 'string') return;
    if (hexString.charAt(0) !== '#') {
        hexString = '#' + hexString;
    }
    if (hexString.length === 4) {
        var split = hexString.split('');
        hexString = '#' + split[1] + split[1] + split[2] + split[2] + split[3] + split[3];
    }
    cordova.exec(null, null, 'StatusBar', 'navigationBackgroundColorByHexString', [hexString]);
};

StatusBar.prototype.hide = function () {
    cordova.exec(null, null, 'StatusBar', 'hide', []);
    StatusBar.isVisible = false;
};

StatusBar.prototype.show = function () {
    cordova.exec(null, null, 'StatusBar', 'show', []);
    StatusBar.isVisible = true;
};

module.exports = new StatusBar();
module.exports.StatusBar = module.exports;

// For ES module import support
if (typeof window !== 'undefined' && window.cordova && window.cordova.plugins) {
    window.cordova.plugins.StatusBar = module.exports;
}