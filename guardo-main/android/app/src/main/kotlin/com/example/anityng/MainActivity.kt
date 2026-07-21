package com.example.anityng

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import com.example.anityng.mpv.MpvPlayerPlugin
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterActivity() {
	private val channelName = "anityng/torrent_native"
	private var baseUrl: String = "http://10.0.2.2:9876"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		flutterEngine.plugins.add(MpvPlayerPlugin())

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"setBaseUrl" -> handleSetBaseUrl(call, result)
					"health" -> handleHealth(result)
					"addTorrent" -> handleAddTorrent(call, result)
					"getTorrentInfo" -> handleGetTorrentInfo(call, result)
					"listTorrents" -> handleListTorrents(result)
					"removeTorrent" -> handleRemoveTorrent(call, result)
					"getStreamUrl" -> handleGetStreamUrl(call, result)
					else -> result.notImplemented()
				}
			}
	}

	private fun handleSetBaseUrl(call: MethodCall, result: MethodChannel.Result) {
		val newBaseUrl = call.argument<String>("baseUrl")?.trim()
		if (newBaseUrl.isNullOrEmpty()) {
			result.error("INVALID_ARGUMENT", "baseUrl is required", null)
			return
		}
		baseUrl = newBaseUrl.trimEnd('/')
		result.success(null)
	}

	private fun handleHealth(result: MethodChannel.Result) {
		runBackground(result) {
			val response = httpRequest("$baseUrl/health", "GET")
			response.code in 200..299
		}
	}

	private fun handleAddTorrent(call: MethodCall, result: MethodChannel.Result) {
		val magnetLink = call.argument<String>("magnetLink")
		val infoHash = call.argument<String>("infoHash")

		if (magnetLink.isNullOrBlank() && infoHash.isNullOrBlank()) {
			result.error("INVALID_ARGUMENT", "magnetLink or infoHash required", null)
			return
		}

		val payload = JSONObject().apply {
			if (!magnetLink.isNullOrBlank()) put("magnetLink", magnetLink)
			if (!infoHash.isNullOrBlank()) put("infoHash", infoHash)
		}.toString()

		runBackground(result) {
			val response = httpRequest("$baseUrl/add", "POST", payload)
			if (response.code !in 200..299) {
				throw IllegalStateException("addTorrent failed: ${response.code} ${response.body}")
			}
			response.body
		}
	}

	private fun handleGetTorrentInfo(call: MethodCall, result: MethodChannel.Result) {
		val infoHash = call.argument<String>("infoHash")
		if (infoHash.isNullOrBlank()) {
			result.error("INVALID_ARGUMENT", "infoHash required", null)
			return
		}

		runBackground(result) {
			val response = httpRequest("$baseUrl/torrent/$infoHash", "GET")
			if (response.code !in 200..299) {
				throw IllegalStateException("getTorrentInfo failed: ${response.code} ${response.body}")
			}
			response.body
		}
	}

	private fun handleListTorrents(result: MethodChannel.Result) {
		runBackground(result) {
			val response = httpRequest("$baseUrl/list", "GET")
			if (response.code !in 200..299) {
				throw IllegalStateException("listTorrents failed: ${response.code} ${response.body}")
			}
			response.body
		}
	}

	private fun handleRemoveTorrent(call: MethodCall, result: MethodChannel.Result) {
		val infoHash = call.argument<String>("infoHash")
		val deleteFiles = call.argument<Boolean>("deleteFiles") ?: false
		if (infoHash.isNullOrBlank()) {
			result.error("INVALID_ARGUMENT", "infoHash required", null)
			return
		}

		val payload = JSONObject().apply { put("deleteFiles", deleteFiles) }.toString()
		runBackground(result) {
			val response = httpRequest("$baseUrl/torrent/$infoHash", "DELETE", payload)
			response.code in 200..299
		}
	}

	private fun handleGetStreamUrl(call: MethodCall, result: MethodChannel.Result) {
		val infoHash = call.argument<String>("infoHash")
		val fileIndex = call.argument<Int>("fileIndex")

		if (infoHash.isNullOrBlank() || fileIndex == null) {
			result.error("INVALID_ARGUMENT", "infoHash and fileIndex required", null)
			return
		}

		result.success("$baseUrl/stream/$infoHash/$fileIndex")
	}

	private fun <T> runBackground(result: MethodChannel.Result, task: () -> T) {
		Thread {
			try {
				val value = task()
				runOnUiThread { result.success(value) }
			} catch (e: Exception) {
				runOnUiThread { result.error("TORRENT_NATIVE_ERROR", e.message, null) }
			}
		}.start()
	}

	private fun httpRequest(url: String, method: String, body: String? = null): HttpResponse {
		val conn = (URL(url).openConnection() as HttpURLConnection).apply {
			requestMethod = method
			connectTimeout = 8000
			readTimeout = 60000
			setRequestProperty("Accept", "application/json")
			if (body != null) {
				doOutput = true
				setRequestProperty("Content-Type", "application/json")
			}
		}

		if (body != null) {
			conn.outputStream.use { os ->
				os.write(body.toByteArray(Charsets.UTF_8))
			}
		}

		val code = conn.responseCode
		val stream = if (code in 200..299) conn.inputStream else conn.errorStream
		val text = stream?.use { s ->
			BufferedReader(InputStreamReader(s)).readText()
		} ?: ""

		conn.disconnect()
		return HttpResponse(code, text)
	}

	private data class HttpResponse(
		val code: Int,
		val body: String,
	)
}
