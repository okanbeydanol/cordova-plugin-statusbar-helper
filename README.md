# [Cordova StatusBar](https://github.com/okanbeydanol/cordova-plugin-statusbar-helper) [![Release](https://img.shields.io/npm/v/cordova-plugin-statusbar-helper.svg?style=flat)](https://github.com/okanbeydanol/cordova-plugin-statusbar-helper/releases)

Change statusBar and navigationBar background color or hide or show.

* This plugin is built for `cordova@^3.6`.

* This plugin currently supports Android and iOS.


## Plugin setup

Using this plugin requires [Cordova iOS](https://github.com/apache/cordova-ios) and [Cordova Android](https://github.com/apache/cordova-android).

1. `cordova plugin add cordova-plugin-statusbar-helper`--save

### Usage

#### JavaScript (Global Cordova)
After the device is ready, you can use the plugin via the global `cordova.plugins.StatusBar` object:

```javascript
var StatusBar = cordova.plugins.StatusBar;

// Overlay the webview with the status bar (true/false)
StatusBar.overlaysWebView(false);

// Set status bar background color by hex string
StatusBar.backgroundColorByHexString('#FF0000');

// Set status bar background color by color name
StatusBar.backgroundColorByName('blue');

// Set navigation bar color (Android only)
StatusBar.navigationBackgroundColorByHexString('#00FF00');

// Hide the status bar
StatusBar.hide();

// Show the status bar
StatusBar.show();

// Check if status bar is ready and visible
StatusBar.isReady(function(visible) {
    console.log('StatusBar is visible:', visible);
});
```

* Check the [JavaScript source](https://github.com/okanbeydanol/cordova-plugin-statusbar-helper/tree/master/www/StatusBar.js) for additional configuration.

#### TypeScript / ES Module / Ionic
You can also use ES module imports (with TypeScript support):

```typescript
import { StatusBar } from 'cordova-plugin-statusbar-helper';

// Overlay the webview with the status bar (true/false)
StatusBar.overlaysWebView(false);

// Set status bar background color by hex string
StatusBar.backgroundColorByHexString('#FF0000');

// Set status bar background color by color name
StatusBar.backgroundColorByName('blue');

// Set navigation bar color (Android only)
StatusBar.navigationBackgroundColorByHexString('#00FF00');

// Hide the status bar
StatusBar.hide();

// Show the status bar
StatusBar.show();

// Use TypeScript types for autocompletion
StatusBar.isReady((visible: boolean) => {
    console.log('StatusBar is visible:', visible);
});
```

TypeScript Types  
Type definitions are included. You get full autocompletion and type safety in TypeScript/Ionic projects.

* Check the [Typescript definitions](https://github.com/okanbeydanol/cordova-plugin-statusbar-helper/tree/master/www/StatusBar.d.ts) for additional


## Communication

- If you **need help**, use [Stack Overflow](http://stackoverflow.com/questions/tagged/cordova). (Tag `cordova`)
- If you **found a bug** or **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.



## Contributing

Patches welcome! Please submit all pull requests against the master branch. If your pull request contains JavaScript patches or features, include relevant unit tests. Thanks!

## Copyright and license

    The MIT License (MIT)

    Copyright (c) 2024 Okan Beydanol

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.