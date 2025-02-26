package com.zegocloud.uikit.zego_uikit_plugin;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.Context;
import android.content.IntentFilter;
import android.content.BroadcastReceiver;
import android.content.Intent;
import android.os.Build;
import android.util.Log;
import android.app.KeyguardManager;
import android.os.PowerManager;
import android.view.WindowManager;
import im.zego.uikit.libuikitreport.*;
import java.util.Map;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import java.util.List;

/**
 * ZegoUikitPlugin
 */
public class ZegoUikitPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel methodChannel;
    private Context context;
    private ActivityPluginBinding activityBinding;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        Log.d("uikit plugin", "onAttachedToEngine");

        methodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "zego_uikit_plugin");
        methodChannel.setMethodCallHandler(this);

        context = flutterPluginBinding.getApplicationContext();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        Log.d("uikit plugin", "onMethodCall: " + call.method);

        if (call.method.equals(Defines.FLUTTER_API_FUNC_BACK_TO_DESKTOP)) {
            Boolean nonRoot = call.argument(Defines.FLUTTER_PARAM_NON_ROOT);

            backToDesktop(nonRoot);

            result.success(null);
        } else if(call.method.equals(Defines.FLUTTER_API_FUNC_IS_LOCK_SCREEN)) {
            result.success(isLockScreen());
        } else if (call.method.equals(Defines.FLUTTER_API_FUNC_CHECK_APP_RUNNING)) {
            result.success(isAppRunning());
        } else if (call.method.equals(Defines.FLUTTER_API_FUNC_ACTIVE_APP_TO_FOREGROUND)) {
            activeAppToForeground(context);
            result.success(null);
        } else if (call.method.equals(Defines.FLUTTER_API_FUNC_REQUEST_DISMISS_KEYGUARD)) {
            requestDismissKeyguard(context, activityBinding.getActivity());

            result.success(null);
        } else if (call.method.equals(Defines.FLUTTER_API_FUNC_REPORTER_CREATE)) {
            int appID = call.argument("app_id");
            String signOrToken = call.argument("sign_token");
            Map<String, Object> commonParams = call.argument("params");

            ReportUtil.create(appID, signOrToken, commonParams);
            result.success(null);
        } else if (call.method.equals(Defines.FLUTTER_API_FUNC_REPORTER_DESTROY)) {
            ReportUtil.destroy();
            result.success(null);
        } else if (call.method.equals(Defines.FLUTTER_API_FUNC_REPORTER_UPDATE_TOKEN)) {
            String token = call.argument("token");

            ReportUtil.updateToken(token);
            result.success(null);
        } else if (call.method.equals(Defines.FLUTTER_API_FUNC_REPORTER_UPDATE_COMMON_PARAMS)) {
            Map<String, Object> commonParams = call.argument("params");

            ReportUtil.updateCommonParams(commonParams);
            result.success(null);
        } else if (call.method.equals(Defines.FLUTTER_API_FUNC_REPORTER_EVENT)) {
            String event = call.argument("event");
            Map<String, Object> paramsMap = call.argument("params");

            ReportUtil.reportEvent(event, paramsMap);
            result.success(null);
        } else {
            result.notImplemented();
        }
    }
    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        Log.d("uikit plugin", "onDetachedFromEngine");

        methodChannel.setMethodCallHandler(null);
    }
    @Override
    public void onAttachedToActivity(ActivityPluginBinding activityPluginBinding) {
        Log.d("uikit plugin", "onAttachedToActivity");

        activityBinding = activityPluginBinding;
    }
    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding activityPluginBinding) {
        Log.d("uikit plugin", "onReattachedToActivityForConfigChanges");

        activityBinding = activityPluginBinding;
    }
    @Override
    public void onDetachedFromActivityForConfigChanges() {
        Log.d("uikit plugin", "onDetachedFromActivityForConfigChanges");

        activityBinding = null;
    }
    @Override
    public void onDetachedFromActivity() {
        Log.d("uikit plugin", "onDetachedFromActivity");

        activityBinding = null;
    }
    public void backToDesktop(Boolean nonRoot) {
        Log.i("uikit plugin", "backToDesktop" + " nonRoot:" + nonRoot);

        try {
            activityBinding.getActivity().moveTaskToBack(nonRoot);
        } catch (Exception e) {
            Log.e("uikit plugin, backToDesktop", e.toString());
        }
    }
    public Boolean isLockScreen() {
        Log.i("uikit plugin", "isLockScreen");

        KeyguardManager keyguardManager = (KeyguardManager) context.getSystemService(Context.KEYGUARD_SERVICE);
        boolean inKeyguardRestrictedInputMode = keyguardManager.inKeyguardRestrictedInputMode();

        boolean isLocked;
        if (inKeyguardRestrictedInputMode) {
            isLocked = true;
        } else {
            PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                isLocked = !powerManager.isInteractive();
            } else {
                isLocked = !powerManager.isScreenOn();
            }
        }

        return isLocked;
    }
    private boolean isAppRunning() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.CUPCAKE) {
            ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
            List<ActivityManager.RunningAppProcessInfo> runningAppProcesses = activityManager.getRunningAppProcesses();
            if (runningAppProcesses != null) {
                for (ActivityManager.RunningAppProcessInfo processInfo : runningAppProcesses) {
                    Log.d("uikit plugin", "running app: " + processInfo.processName);

                    if (processInfo.processName.equals(context.getPackageName())) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    public void activeAppToForeground(Context context) {
        Log.d("uikit plugin", "active app to foreground");

        String packageName = context.getPackageName();
        if (Build.VERSION.SDK_INT < 29) {
            // 获取ActivityManager
            ActivityManager am = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
            // 获取任务列表
            List<ActivityManager.AppTask> appTasks = null;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                appTasks = am.getAppTasks();
            }
            if (appTasks == null || appTasks.isEmpty()) {
                Log.d("uikit plugin", "app task null");
                return;
            }

            // Android 10以下版本，可以直接调用moveTaskToFront将任务带到前台
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                for (ActivityManager.AppTask appTask : appTasks) {
                    if (appTask.getTaskInfo().baseActivity.getPackageName().equals(packageName)) {
                        appTask.moveToFront();
                        return;
                    }
                }
            } else {
                // 对于 API 23以下的版本，启动一个新的Activity来将应用带到前台
                Intent intent = null;
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.CUPCAKE) {
                    intent = context.getPackageManager().getLaunchIntentForPackage(packageName);
                }
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
                    context.startActivity(intent);
                }
            }
        } else {
            // Android 10以上版本，需要通过启动intent来将应用带到前台
            Intent intent = context.getPackageManager().getLaunchIntentForPackage(packageName);
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
                context.getApplicationContext().startActivity(intent);
            }
        }
    }

    public void requestDismissKeyguard(Context context, Activity activity) {
        Log.d("uikit plugin", "request dismiss keyguard");

        if (null == activity) {
            Log.d("uikit plugin", "request dismiss keyguard, activity is null");
            return;
        }

        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.N_MR1) {
            KeyguardManager keyguardManager = (KeyguardManager) context.getSystemService(Context.KEYGUARD_SERVICE);
            if (keyguardManager.isKeyguardLocked()) {
                keyguardManager.requestDismissKeyguard(activity, null);
            }
        } else {
            WindowManager.LayoutParams params = activity.getWindow().getAttributes();
            params.flags |= WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED;
            params.flags |= WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD;
            activity.getWindow().setAttributes(params);
        }
    }
}