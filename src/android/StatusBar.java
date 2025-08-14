package com.okanbeydanol.statusBar;

import android.graphics.Color;
import android.os.Build;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.graphics.ColorUtils;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONException;

public class StatusBar extends CordovaPlugin {
    private static final String ACTION_HIDE = "hide";
    private static final String ACTION_SHOW = "show";
    private static final String ACTION_READY = "_ready";
    private static final String ACTION_BACKGROUND_COLOR_BY_HEX_STRING = "backgroundColorByHexString";
    private static final String ACTION_NAVIGATION_BACKGROUND_COLOR_BY_HEX_STRING = "navigationBackgroundColorByHexString";
    private static final String ACTION_OVERLAYS_WEB_VIEW = "overlaysWebView";
    private static final String STYLE_DEFAULT = "default";
    private static final String STYLE_LIGHT_CONTENT = "lightcontent";
    private static final String ACTION_STYLE_DEFAULT = "styleDefault";
    private static final String ACTION_STYLE_LIGHT_CONTENT = "styleLightContent";

    private AppCompatActivity activity;
    private Window window;

    @Override
    protected void pluginInitialize() {
        activity = cordova.getActivity();
        if (activity == null) return;

        window = activity.getWindow();
        runOnUiThread(() -> {
            window.clearFlags(WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN
                | WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
            window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);

            setStatusBarTransparent(false);
            window.getDecorView().post(this::setSystemBarColors);
        });
    }

    @Override
    public boolean execute(String action, CordovaArgs args, CallbackContext callbackContext) {
        switch (action) {
            case ACTION_READY:
                boolean visible = (window.getAttributes().flags & WindowManager.LayoutParams.FLAG_FULLSCREEN) == 0;
                callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, visible));
                return true;

            case ACTION_SHOW:
                showSystemBars();
                callbackContext.success();
                return true;

            case ACTION_HIDE:
                hideSystemBars();
                callbackContext.success();
                return true;

            case ACTION_BACKGROUND_COLOR_BY_HEX_STRING:
                runOnUiThreadSafe(() -> {
                    try {
                        setStatusBarColor(args.getString(0));
                        callbackContext.success();
                    } catch (JSONException e) {
                        callbackContext.error("Invalid hex string for status bar");
                    }
                });
                return true;

            case ACTION_NAVIGATION_BACKGROUND_COLOR_BY_HEX_STRING:
                runOnUiThreadSafe(() -> {
                    try {
                        setNavigationBarColor(args.getString(0));
                        callbackContext.success();
                    } catch (JSONException e) {
                        callbackContext.error("Invalid hex string for navigation bar");
                    }
                });
                return true;

            case ACTION_OVERLAYS_WEB_VIEW:
                runOnUiThreadSafe(() -> {
                    try {
                        setStatusBarTransparent(args.getBoolean(0));
                        callbackContext.success();
                    } catch (JSONException e) {
                        callbackContext.error("Invalid boolean argument for overlaysWebView");
                    }
                });
                return true;

            case ACTION_STYLE_DEFAULT:
                runOnUiThreadSafe(() -> {
                    setBarStyle(STYLE_DEFAULT, true);
                    setBarStyle(STYLE_DEFAULT, false);
                    callbackContext.success();
                });
                return true;

            case ACTION_STYLE_LIGHT_CONTENT:
                runOnUiThreadSafe(() -> {
                    setBarStyle(STYLE_LIGHT_CONTENT, true);
                    setBarStyle(STYLE_LIGHT_CONTENT, false);
                    callbackContext.success();
                });
                return true;

            default:
                return false;
        }
    }

    // ====================
    // Colors
    // ====================
    private void setSystemBarColors() {
        setStatusBarColor("#FFFFFF");
        setNavigationBarColor("#FFFFFF");
    }

    private void setStatusBarColor(String hex) {
        Integer color = parseColorSafe(hex);
        if (color == null) return;
        window.setStatusBarColor(color);
        setBarStyle(isLightTextNeeded(color) ? STYLE_LIGHT_CONTENT : STYLE_DEFAULT, true);
    }

    private void setNavigationBarColor(String hex) {
        Integer color = parseColorSafe(hex);
        if (color == null) return;
        window.setNavigationBarColor(color);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.setNavigationBarDividerColor(Color.TRANSPARENT);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.setNavigationBarContrastEnforced(false);
        }

        setBarStyle(isLightTextNeeded(color) ? STYLE_LIGHT_CONTENT : STYLE_DEFAULT, false);
    }

    private Integer parseColorSafe(String hex) {
        if (hex == null || hex.isEmpty()) return null;
        try {
            return Color.parseColor(hex);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private boolean isLightTextNeeded(int color) {
        return ColorUtils.calculateLuminance(color) < 0.5;
    }

    // ====================
    // Styles
    // ====================
    private void setBarStyle(String style, boolean isStatusBar) {
        WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, window.getDecorView());
        boolean light = STYLE_DEFAULT.equals(style);
        if (isStatusBar) {
            controller.setAppearanceLightStatusBars(light);
        } else {
            controller.setAppearanceLightNavigationBars(light);
        }
    }

    // ====================
    // System UI Visibility
    // ====================
    private void setStatusBarTransparent(boolean transparent) {
        int visibility = transparent
            ? View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            : View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_VISIBLE;
        window.getDecorView().setSystemUiVisibility(visibility);

        if (transparent) {
            window.setStatusBarColor(Color.TRANSPARENT);
        } else {
            window.setStatusBarColor(Color.WHITE);
        }
    }

    private void showSystemBars() {
        int uiOptions = window.getDecorView().getSystemUiVisibility();
        uiOptions &= ~View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN;
        uiOptions &= ~View.SYSTEM_UI_FLAG_FULLSCREEN;
        window.getDecorView().setSystemUiVisibility(uiOptions);
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
    }

    private void hideSystemBars() {
        int uiOptions = window.getDecorView().getSystemUiVisibility()
            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            | View.SYSTEM_UI_FLAG_FULLSCREEN;
        window.getDecorView().setSystemUiVisibility(uiOptions);
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
    }

    // ====================
    // Utilities
    // ====================
    private void runOnUiThreadSafe(Runnable r) {
        if (activity != null) activity.runOnUiThread(r);
    }

    private void runOnUiThread(Runnable r) {
        if (activity != null) activity.runOnUiThread(r);
    }
}
