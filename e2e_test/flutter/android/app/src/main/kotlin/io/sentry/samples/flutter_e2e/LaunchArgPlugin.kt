package io.sentry.samples.flutter_e2e

import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class LaunchArgPlugin: ActivityAware, FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null

    private val args: MutableList<String> = ArrayList()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "launchargs")
        channel!!.setMethodCallHandler(this)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        args.clear()

        val activity = binding.activity
        val intent = activity.intent
        if (intent != null) {
            val bundle = intent.extras
            if (bundle != null) {
                val keys = bundle.keySet()

                for (key in keys) {
                    args.add("--$key")
                    args.add(bundle[key].toString())
                }
            }
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        args.clear()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        val bundle = binding.activity.intent.extras
        val keys = bundle!!.keySet()

        args.clear()
        for (key in keys) {
            args.add("--$key")
            args.add(bundle[key].toString())
        }
    }

    override fun onDetachedFromActivity() {
        args.clear()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android " + Build.VERSION.RELEASE)
        } else if (call.method == "args") {
            result.success(args)
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        channel!!.setMethodCallHandler(null)
    }
}