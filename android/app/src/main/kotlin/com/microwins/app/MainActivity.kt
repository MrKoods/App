package com.microwins.app

import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	private val focusLockChannel = "microwins/focus_lock"

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