package com.okanbeydanol.statusBar;

import android.content.Context;
import android.graphics.Color;
import android.os.Build;
import android.view.View;
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
    private static final String ACTION_STYLE_DEFAULT = "styleDefault";
    private static final String ACTION_STYLE_LIGHT_CONTENT = "styleLightContent";
    private static final String ACTION_GET_SAFEAREA_INSETS = "getSafeAreaInsets";
    private static final String ACTION_SUBSCRIBE_SAFEAREA_INSETS = "subscribeSafeAreaInsets";

    private static final String STYLE_DEFAULT = "default";
    private static final String STYLE_LIGHT_CONTENT = "lightcontent";

    private AppCompatActivity activity;
    private Window window;
    private View rootView;
    private boolean fullScreenAppEnabled = false;

    @Override
    protected void pluginInitialize() {
        activity = cordova.getActivity();
        if (activity == null) return;

        rootView = this.webView.getView().getRootView();
        window = activity.getWindow();
        runOnUiThread(() -> {
            window.clearFlags(WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN | WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
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
                boolean keepInsetsShow = false;
                if (args != null && !args.isNull(0)) {
                    keepInsetsShow = args.optBoolean(0);
                }
                showSystemBars(keepInsetsShow);
                callbackContext.success();
                return true;

            case ACTION_HIDE:
                boolean keepInsetsHide = false;
                if (args != null && !args.isNull(0)) {
                    keepInsetsHide = args.optBoolean(0);
                }
                hideSystemBars(keepInsetsHide);
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
    // Colors & Styles
    // ====================
    private void setSystemBarColors() {
        setStatusBarColor("#FFFFFF");
        setNavigationBarColor("#FFFFFF");
    }

    private void setStatusBarColor(String hex) {
        Integer color = parseColorSafe(hex);
        if (color == null) return;

        window.setStatusBarColor(fullScreenAppEnabled || isEdgeToEdge() ? Color.TRANSPARENT : color);
        if (isEdgeToEdge()) {
            rootView.setBackgroundColor(fullScreenAppEnabled ? Color.TRANSPARENT : color);
        }

        setBarStyle(isLightTextNeeded(color) ? STYLE_LIGHT_CONTENT : STYLE_DEFAULT, true);
    }

    private void setNavigationBarColor(String hex) {
        Integer color = parseColorSafe(hex);
        if (color == null) return;

        window.setNavigationBarColor(fullScreenAppEnabled || isEdgeToEdge() ? Color.TRANSPARENT : color);

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
    // System UI
    // ====================
    private void overlaysWebView(boolean enableFullScreen) {
        fullScreenAppEnabled = enableFullScreen;

        final View decorView = window.getDecorView();
        int visibility;
        int statusBarColor;

        if (enableFullScreen) {
            visibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN;
            statusBarColor = Color.TRANSPARENT;
            updateWebViewInsets(false);
        } else if (isEdgeToEdge()) {
            visibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN;
            statusBarColor = Color.TRANSPARENT;
            updateWebViewInsets(true);
        } else {
            visibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_VISIBLE;
            statusBarColor = Color.WHITE;
            updateWebViewInsets(false);
        }

        decorView.setSystemUiVisibility(visibility);
        window.setStatusBarColor(statusBarColor);
        window.setNavigationBarColor(statusBarColor);
    }

    private void showSystemBars(boolean keepInsets) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, rootView);
            controller.show(WindowInsetsCompat.Type.statusBars() | WindowInsetsCompat.Type.navigationBars());
        } else {
            int uiOptions = window.getDecorView().getSystemUiVisibility();
            uiOptions &= ~View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN;
            uiOptions &= ~View.SYSTEM_UI_FLAG_FULLSCREEN;
            window.getDecorView().setSystemUiVisibility(uiOptions);
        }
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
        if (!keepInsets) {
            updateWebViewInsets(isEdgeToEdge() && !fullScreenAppEnabled);
        }
    }

    private void hideSystemBars(boolean keepInsets) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, rootView);
            controller.hide(WindowInsetsCompat.Type.statusBars() | WindowInsetsCompat.Type.navigationBars());
        } else {
            int uiOptions = window.getDecorView().getSystemUiVisibility()
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_FULLSCREEN;
            window.getDecorView().setSystemUiVisibility(uiOptions);
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
        if(!keepInsets){
            updateWebViewInsets(false);
        }
    }

    // ====================
    // Safe Area Insets
    // ====================
    private void updateWebViewInsets(boolean enableInsets) {
        if (enableInsets) {
            applyInsets(rootView);
            ViewCompat.setOnApplyWindowInsetsListener(rootView, (v, insets) -> {
                applyInsets(v);
                return insets;
            });
        } else {
            rootView.setPadding(0, 0, 0, 0);
            ViewCompat.setOnApplyWindowInsetsListener(rootView, null);
        }
    }

    private void applyInsets(View v) {
        WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(v);
        if (insets == null) return;

        Insets systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
        Insets imeInsets = insets.getInsets(WindowInsetsCompat.Type.ime());
        boolean keyboardVisible = insets.isVisible(WindowInsetsCompat.Type.ime());

        int top = systemBars.top;
        int bottom = keyboardVisible ? Math.max(systemBars.bottom, imeInsets.bottom) : systemBars.bottom;
        int left = systemBars.left;
        int right = systemBars.right;

        v.setPadding(left, top, right, bottom);
    }

    private void getSafeAreaInsets(CallbackContext callbackContext) {
        try {
            Context ctx = activity;
            JSONObject obj = new JSONObject();
            obj.put("top", toDIPFromPixel(ctx, rootView.getPaddingTop()));
            obj.put("left", toDIPFromPixel(ctx, rootView.getPaddingLeft()));
            obj.put("bottom", toDIPFromPixel(ctx, rootView.getPaddingBottom()));
            obj.put("right", toDIPFromPixel(ctx, rootView.getPaddingRight()));

            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, obj));
        } catch (Exception e) {
            callbackContext.error("JSON error: " + e.getMessage());
        }
    }

    private void subscribeSafeAreaInsets(CallbackContext callbackContext) {
        PluginResult initial = new PluginResult(PluginResult.Status.OK, new JSONObject());
        initial.setKeepCallback(true);
        callbackContext.sendPluginResult(initial);

        rootView.getViewTreeObserver().addOnGlobalLayoutListener(() -> getSafeAreaInsets(callbackContext));
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

    private boolean isEdgeToEdge() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q; // Android 10+
    }

    public static float toDIPFromPixel(Context context, float px) {
        float density = context.getResources().getDisplayMetrics().density;
        return px / density;
    }
}
