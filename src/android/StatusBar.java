package com.okanbeydanol.statusBar;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.Rect;
import android.os.Build;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.graphics.ColorUtils;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONException;
import org.json.JSONObject;

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
    private static final String ACTION_GET_SAFEAREA_INSETS = "getSafeAreaInsets";
    private static final String ACTION_SUBSCRIBE_SAFEAREA_INSETS = "subscribeSafeAreaInsets";
    private AppCompatActivity activity;
    private Window window;
    private View rootView;
    private final boolean edgeToEdge = isEdgeToEdgeSupported();
    private boolean fullScreenAppEnabled = false;

    @Override
    protected void pluginInitialize() {
        rootView = this.webView.getView().getRootView();
        activity = cordova.getActivity();
        if (activity == null) return;

        window = activity.getWindow();
        runOnUiThread(() -> {

            window.clearFlags(WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN
                | WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
            window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);

            final View decorView = window.getDecorView();
            // Use post to run code after the view is attached and measured.
            decorView.post(() -> {
                if (edgeToEdge) {
                    rootView.setBackgroundColor(Color.WHITE);
                }
                setSystemBarColors();
                overlaysWebView(false);
            });
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
                        overlaysWebView(args.getBoolean(0));
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

            case ACTION_GET_SAFEAREA_INSETS:
                runOnUiThreadSafe(() -> getSafeAreaInsets(callbackContext));
                return true;

            case ACTION_SUBSCRIBE_SAFEAREA_INSETS:
                runOnUiThreadSafe(() -> subscribeSafeAreaInsets(callbackContext));
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

    private boolean isEdgeToEdgeSupported() {
        // Android 12+ (API 31+) is considered edge-to-edge capable
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.S;
    }

    private void setStatusBarColor(String hex) {
        Integer color = parseColorSafe(hex);
        if (color == null) return;

        window.setStatusBarColor(fullScreenAppEnabled ? Color.TRANSPARENT : color);
        if (isEdgeToEdgeSupported()) {
            rootView.setBackgroundColor(fullScreenAppEnabled ? Color.TRANSPARENT : color);
        }
        setBarStyle(isLightTextNeeded(color) ? STYLE_LIGHT_CONTENT : STYLE_DEFAULT, true);
    }

    private void setNavigationBarColor(String hex) {
        Integer color = parseColorSafe(hex);
        if (color == null) return;
        window.setNavigationBarColor(fullScreenAppEnabled ? Color.TRANSPARENT : color);

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
    private void overlaysWebView(boolean enableFullScreen) {
        fullScreenAppEnabled = enableFullScreen;

        final View decorView = window.getDecorView();
        int visibility;
        int statusBarColor;

        if (enableFullScreen) {
            // Fullscreen: status bar transparent, no WebView insets
            visibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN;
            statusBarColor = Color.TRANSPARENT;
            updateWebViewInsets(false);
        } else if (edgeToEdge) {
            // Edge-to-edge app: status bar transparent but WebView has system bars insets
            visibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN;
            statusBarColor = Color.TRANSPARENT;
            updateWebViewInsets(true);
        } else {
            // Normal app: status bar visible with white background, WebView has no insets
            visibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_VISIBLE;
            statusBarColor = Color.WHITE;
            updateWebViewInsets(false);
        }

        decorView.setSystemUiVisibility(visibility);
        window.setStatusBarColor(statusBarColor);
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

    private void updateWebViewInsets(boolean enableInsets) {
        if (enableInsets) {
            // Apply system bars + keyboard insets as padding
            WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(rootView);
            if (insets != null) {
                Insets systemBars = insets.getInsets(
                    WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout()
                );
                Insets imeInsets = insets.getInsets(WindowInsetsCompat.Type.ime());
                boolean keyboardVisible = insets.isVisible(WindowInsetsCompat.Type.ime());

                int top = systemBars.top;
                int bottom = keyboardVisible ? Math.max(systemBars.bottom, imeInsets.bottom)  : systemBars.bottom;
                int left = systemBars.left;
                int right = systemBars.right;

                rootView.setPadding(left, top, right, bottom);
            }

            // Update dynamically when insets change
            ViewCompat.setOnApplyWindowInsetsListener(rootView, (v, windowInsets) -> {
                Insets systemBarsListener = windowInsets.getInsets(
                    WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout()
                );
                Insets imeInsetsListener = windowInsets.getInsets(WindowInsetsCompat.Type.ime());
                boolean keyboardVisibleListener = windowInsets.isVisible(WindowInsetsCompat.Type.ime());

                int top = systemBarsListener.top;
                int bottom = keyboardVisibleListener ? Math.max(systemBarsListener.bottom, imeInsetsListener.bottom) : systemBarsListener.bottom;
                int left = systemBarsListener.left;
                int right = systemBarsListener.right;

                v.setPadding(left, top, right, bottom);
                return WindowInsetsCompat.CONSUMED;
            });

        } else {
            // Remove all insets
            rootView.setPadding(0, 0, 0, 0);
            ViewCompat.setOnApplyWindowInsetsListener(rootView, null);
        }
    }

    private void getSafeAreaInsets(CallbackContext callbackContext) {
        try {
            int top = rootView.getPaddingTop();
            int left = rootView.getPaddingLeft();
            int bottom = rootView.getPaddingBottom();
            int right = rootView.getPaddingRight();
            JSONObject obj = new JSONObject();
            obj.put("top", top);
            obj.put("left", left);
            obj.put("bottom", bottom);
            obj.put("right", right);

            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, obj));

        } catch (Exception e) {
            callbackContext.error("JSON error: " + e.getMessage());
        }
    }

    private void subscribeSafeAreaInsets(CallbackContext callbackContext) {
        PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, new JSONObject());
        pluginResult.setKeepCallback(true);
        callbackContext.sendPluginResult(pluginResult);

        ViewCompat.setOnApplyWindowInsetsListener(rootView, (v, insets) -> {
            int top = v.getPaddingTop();
            int left = v.getPaddingLeft();
            int bottom = v.getPaddingBottom();
            int right = v.getPaddingRight();

            try {
                JSONObject obj = new JSONObject();
                obj.put("top", top);
                obj.put("left", left);
                obj.put("bottom", bottom);
                obj.put("right", right);

                PluginResult result = new PluginResult(PluginResult.Status.OK, obj);
                result.setKeepCallback(true);
                callbackContext.sendPluginResult(result);

            } catch (JSONException e) {
                callbackContext.error("JSON error");
            }

            return insets;
        });
    }
}
