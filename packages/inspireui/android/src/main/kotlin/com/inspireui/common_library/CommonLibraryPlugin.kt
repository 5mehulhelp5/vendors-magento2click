package com.inspireui.common_library

import android.app.Activity
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Base64
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** CommonLibraryPlugin */
class CommonLibraryPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  private lateinit var context: Context
  private lateinit var activity: Activity

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.inspireui/common_library")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

   override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
  //   if (call.method == "UGxlYXNlIHVzZSB0aGUgbGVnYWwgTGljZW5zZSDwn5mP") {
  //     val app: ApplicationInfo = context.packageManager.getApplicationInfo(
  //             context.packageName, PackageManager.GET_META_DATA)
  //     val bundle: Bundle = app.metaData
  //     val data: ByteArray = Base64.decode(
  //             "Y29tLmluc3BpcmV1aS5FTlZBVE9fUFVSQ0hBU0VfQ09ERQ==", Base64.DEFAULT)
  //     val text = String(data, Charsets.UTF_8)
  //     result.success(bundle.getString(text))
  //   } else {s
  //     result.notImplemented()
  //   }
   }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    context = activity.applicationContext
  }

  override fun onDetachedFromActivityForConfigChanges() {}

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

  override fun onDetachedFromActivity() {}
}
