package uk.bw86.nscgschedule

import android.os.Bundle
import com.google.android.gms.wearable.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var dataClient: DataClient
    private lateinit var nodeClient: NodeClient

    companion object {
        private const val CHANNEL = "uk.bw86.nscgschedule/watch"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        dataClient = Wearable.getDataClient(this)
        nodeClient = Wearable.getNodeClient(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isConnected" -> {
                    scope.launch {
                        try {
                            val nodes = nodeClient.connectedNodes.await()
                            result.success(nodes.isNotEmpty())
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                "sendData" -> {
                    scope.launch {
                        try {
                            val path = call.argument<String>("path") ?: "/watch_data"
                            val jsonData = call.argument<String>("data") ?: ""

                            // Create PutDataRequest with JSON string as byte array
                            val request = PutDataMapRequest.create(path).apply {
                                dataMap.putString("json", jsonData)
                                dataMap.putLong("timestamp", System.currentTimeMillis())
                            }.asPutDataRequest().setUrgent()

                            dataClient.putDataItem(request).await()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SEND_ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
