declare namespace CordovaPlugins {
    interface StatusBar {
        isVisible: boolean;
        isReady(callback?: (visible: boolean) => void): void;
        overlaysWebView(doOverlay: boolean): void;
        backgroundColorByName(colorname: string): void;
        backgroundColorByHexString(hexString: string): void;
        navigationBackgroundColorByHexString(hexString: string): void;
        hide(): void;
        show(): void;
        styleDefault(): void;
        styleLightContent(): void;
    }
}

interface CordovaPlugins {
    StatusBar: CordovaPlugins.StatusBar;
}

interface Cordova {
    plugins: CordovaPlugins;
}

declare let cordova: Cordova;

export const StatusBar: CordovaPlugins.StatusBar;
export as namespace StatusBar;
declare const _default: CordovaPlugins.StatusBar;
export default _default;