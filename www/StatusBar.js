function StatusBar() { }
// Standard CSS color names mapped to hex values
var namedColors = {
    aliceblue: '#F0F8FF',
    antiquewhite: '#FAEBD7',
    aqua: '#00FFFF',
    aquamarine: '#7FFFD4',
    azure: '#F0FFFF',
    beige: '#F5F5DC',
    bisque: '#FFE4C4',
    black: '#000000',
    blanchedalmond: '#FFEBCD',
    blue: '#0000FF',
    blueviolet: '#8A2BE2',
    brown: '#A52A2A',
    burlywood: '#DEB887',
    cadetblue: '#5F9EA0',
    chartreuse: '#7FFF00',
    chocolate: '#D2691E',
    coral: '#FF7F50',
    cornflowerblue: '#6495ED',
    cornsilk: '#FFF8DC',
    crimson: '#DC143C',
    cyan: '#00FFFF',
    darkblue: '#00008B',
    darkcyan: '#008B8B',
    darkgoldenrod: '#B8860B',
    darkgray: '#A9A9A9',
    darkgreen: '#006400',
    darkkhaki: '#BDB76B',
    darkmagenta: '#8B008B',
    darkolivegreen: '#556B2F',
    darkorange: '#FF8C00',
    darkorchid: '#9932CC',
    darkred: '#8B0000',
    darksalmon: '#E9967A',
    darkseagreen: '#8FBC8F',
    darkslateblue: '#483D8B',
    darkslategray: '#2F4F4F',
    darkturquoise: '#00CED1',
    darkviolet: '#9400D3',
    deeppink: '#FF1493',
    deepskyblue: '#00BFFF',
    dimgray: '#696969',
    dodgerblue: '#1E90FF',
    firebrick: '#B22222',
    floralwhite: '#FFFAF0',
    forestgreen: '#228B22',
    fuchsia: '#FF00FF',
    gainsboro: '#DCDCDC',
    ghostwhite: '#F8F8FF',
    gold: '#FFD700',
    goldenrod: '#DAA520',
    gray: '#808080',
    green: '#008000',
    greenyellow: '#ADFF2F',
    honeydew: '#F0FFF0',
    hotpink: '#FF69B4',
    indianred: '#CD5C5C',
    indigo: '#4B0082',
    ivory: '#FFFFF0',
    khaki: '#F0E68C',
    lavender: '#E6E6FA',
    lavenderblush: '#FFF0F5',
    lawngreen: '#7CFC00',
    lemonchiffon: '#FFFACD',
    lightblue: '#ADD8E6',
    lightcoral: '#F08080',
    lightcyan: '#E0FFFF',
    lightgoldenrodyellow: '#FAFAD2',
    lightgray: '#D3D3D3',
    lightgreen: '#90EE90',
    lightpink: '#FFB6C1',
    lightsalmon: '#FFA07A',
    lightseagreen: '#20B2AA',
    lightskyblue: '#87CEFA',
    lightslategray: '#778899',
    lightsteelblue: '#B0C4DE',
    lightyellow: '#FFFFE0',
    lime: '#00FF00',
    limegreen: '#32CD32',
    linen: '#FAF0E6',
    magenta: '#FF00FF',
    maroon: '#800000',
    mediumaquamarine: '#66CDAA',
    mediumblue: '#0000CD',
    mediumorchid: '#BA55D3',
    mediumpurple: '#9370DB',
    mediumseagreen: '#3CB371',
    mediumslateblue: '#7B68EE',
    mediumspringgreen: '#00FA9A',
    mediumturquoise: '#48D1CC',
    mediumvioletred: '#C71585',
    midnightblue: '#191970',
    mintcream: '#F5FFFA',
    mistyrose: '#FFE4E1',
    moccasin: '#FFE4B5',
    navajowhite: '#FFDEAD',
    navy: '#000080',
    oldlace: '#FDF5E6',
    olive: '#808000',
    olivedrab: '#6B8E23',
    orange: '#FFA500',
    orangered: '#FF4500',
    orchid: '#DA70D6',
    palegoldenrod: '#EEE8AA',
    palegreen: '#98FB98',
    paleturquoise: '#AFEEEE',
    palevioletred: '#DB7093',
    papayawhip: '#FFEFD5',
    peachpuff: '#FFDAB9',
    peru: '#CD853F',
    pink: '#FFC0CB',
    plum: '#DDA0DD',
    powderblue: '#B0E0E6',
    purple: '#800080',
    red: '#FF0000',
    rosybrown: '#BC8F8F',
    royalblue: '#4169E1',
    saddlebrown: '#8B4513',
    salmon: '#FA8072',
    sandybrown: '#F4A460',
    seagreen: '#2E8B57',
    seashell: '#FFF5EE',
    sienna: '#A0522D',
    silver: '#C0C0C0',
    skyblue: '#87CEEB',
    slateblue: '#6A5ACD',
    slategray: '#708090',
    snow: '#FFFAFA',
    springgreen: '#00FF7F',
    steelblue: '#4682B4',
    tan: '#D2B48C',
    teal: '#008080',
    thistle: '#D8BFD8',
    tomato: '#FF6347',
    turquoise: '#40E0D0',
    violet: '#EE82EE',
    wheat: '#F5DEB3',
    white: '#FFFFFF',
    whitesmoke: '#F5F5F5',
    yellow: '#FFFF00',
    yellowgreen: '#9ACD32'
};

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
    var hex = namedColors[colorname.toLowerCase()];
    if (!hex) {
        console.warn('StatusBar: Unknown color name:', colorname);
        return;
    }
    return StatusBar.backgroundColorByHexString(hex);
};

StatusBar.prototype.backgroundColorByHexString = function (hexString) {
    if (typeof hexString !== 'string') return;
    if (hexString.charAt(0) !== '#') {
        hexString = '#' + hexString;
    }
    // Expand 3-digit hex to 6-digit
    if (hexString.length === 4) {
        var split = hexString.split('');
        hexString = '#' + split[1] + split[1] + split[2] + split[2] + split[3] + split[3];
    }
    // Validate hex string: #RRGGBB or #RRGGBBAA
    var hexRegex = /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$/;
    if (!hexRegex.test(hexString)) {
        console.warn('StatusBar: Invalid hex color format. Use #RRGGBB or #RRGGBBAA');
        return;
    }
    // Convert #RRGGBBAA to #AARRGGBB for Android
    var isAndroid = typeof cordova !== 'undefined' && cordova.platformId === 'android';
    if (isAndroid && hexString.length === 9) {
        // #RRGGBBAA -> #AARRGGBB
        hexString = '#' + hexString.slice(7, 9) + hexString.slice(1, 7);
    }
    cordova.exec(null, null, 'StatusBar', 'backgroundColorByHexString', [hexString]);
};

StatusBar.prototype.navigationBackgroundColorByHexString = function (hexString) {
    if (typeof hexString !== 'string') return;
    if (hexString.charAt(0) !== '#') {
        hexString = '#' + hexString;
    }
    // Expand 3-digit hex to 6-digit
    if (hexString.length === 4) {
        var split = hexString.split('');
        hexString = '#' + split[1] + split[1] + split[2] + split[2] + split[3] + split[3];
    }
    // Validate hex string: #RRGGBB or #RRGGBBAA
    var hexRegex = /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$/;
    if (!hexRegex.test(hexString)) {
        console.warn('StatusBar: Invalid hex color format. Use #RRGGBB or #RRGGBBAA');
        return;
    }
    // Convert #RRGGBBAA to #AARRGGBB for Android
    var isAndroid = typeof cordova !== 'undefined' && cordova.platformId === 'android';
    if (isAndroid && hexString.length === 9) {
        // #RRGGBBAA -> #AARRGGBB
        hexString = '#' + hexString.slice(7, 9) + hexString.slice(1, 7);
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