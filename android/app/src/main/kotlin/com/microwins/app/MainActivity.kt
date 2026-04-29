package com.microwins.app

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	private val focusLockChannel = "microwins/focus_lock"

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		
		// Enable edge-to-edge display by ensuring system windows don't constrain the view
		WindowCompat.setDecorFitsSystemWindows(window, false)
		
		// Configure the system bars appearance for proper edge-to-edge
		val insetsController = WindowCompat.getInsetsController(window, window.decorView)
		if (insetsController != null) {
			// Show the system bars by default (they can be hidden by immersive mode later)
			insetsController.show(WindowInsetsCompat.Type.systemBars())
			// Configure the system bar behavior to respond to user swipes on Android 12+
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
				insetsController.systemBarsBehavior = 
					WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
			}
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, focusLockChannel)
			.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
				when (call.method) {
					"enterImmersiveMode" -> {
						safelyApplyUiMode(result) { enterImmersiveMode() }
					}
					"exitImmersiveMode" -> {
						safelyApplyUiMode(result) { exitImmersiveMode() }
					}
					"startLockTaskMode" -> {
						safelyApplyLockTask(result) { startLockTask() }
					}
					"stopLockTaskMode" -> {
						safelyApplyLockTask(result) { stopLockTask() }
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun safelyApplyUiMode(
		result: MethodChannel.Result,
		action: () -> Unit,
	) {
		runOnUiThread {
			try {
				action()
				result.success(null)
			} catch (exception: Exception) {
				result.error("IMMERSIVE_MODE_ERROR", exception.message, null)
			}
		}
	}

	private fun safelyApplyLockTask(
		result: MethodChannel.Result,
		action: () -> Unit,
	) {
		runOnUiThread {
			try {
				action()
				result.success(true)
			} catch (exception: Exception) {
				result.success(false)
			}
		}
	}

	private fun enterImmersiveMode() {
		WindowCompat.setDecorFitsSystemWindows(window, false)
		val controller = WindowCompat.getInsetsController(window, window.decorView) ?: return

		controller.systemBarsBehavior =
			WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
		controller.hide(WindowInsetsCompat.Type.systemBars())
	}

	private fun exitImmersiveMode() {
		val controller = WindowCompat.getInsetsController(window, window.decorView)
		controller?.show(WindowInsetsCompat.Type.systemBars())
		WindowCompat.setDecorFitsSystemWindows(window, true)
	}
}