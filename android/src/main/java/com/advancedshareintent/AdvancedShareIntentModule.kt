package com.advancedshareintent

import android.app.Activity
import android.content.ClipData
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.provider.MediaStore
import com.facebook.react.bridge.ActivityEventListener
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule

class AdvancedShareIntentModule(
  private val reactContext: ReactApplicationContext
) : ReactContextBaseJavaModule(reactContext), ActivityEventListener, LifecycleEventListener {
  private val mainHandler = Handler(Looper.getMainLooper())
  private var initialShare: WritableMap? = null
  private var latestShare: WritableMap? = null
  private var hasListeners = false

  init {
    reactContext.addActivityEventListener(this)
    reactContext.addLifecycleEventListener(this)
  }

  override fun getName(): String = NAME

  override fun initialize() {
    super.initialize()
    reactContext.currentActivity?.intent?.let { intent ->
      parseShareIntent(intent, true)?.let { payload ->
        initialShare = payload.copy()
        latestShare = payload.copy()
      }
    }
  }

  override fun onNewIntent(intent: Intent) {
    parseShareIntent(intent, false)?.let { payload ->
      latestShare = payload.copy()
      sendEventWhenReady(payload.copy())
    }
  }

  override fun onActivityResult(
    activity: Activity,
    requestCode: Int,
    resultCode: Int,
    data: Intent?
  ) = Unit

  @ReactMethod
  fun getInitialShare(promise: Promise) {
    try {
      val payload = initialShare ?: reactContext.currentActivity?.intent?.let { parseShareIntent(it, true) }
      initialShare = payload?.copy()
      promise.resolve(payload?.copy())
    } catch (error: Exception) {
      promise.reject("advanced_share_intent_initial_error", error)
    }
  }

  @ReactMethod
  fun clearSharedData(promise: Promise) {
    initialShare = null
    latestShare = null
    reactContext.currentActivity?.intent?.apply {
      action = null
      type = null
      data = null
      clipData = null
      replaceExtras(Bundle())
    }
    promise.resolve(null)
  }

  @ReactMethod
  fun addListener(eventName: String) {
    hasListeners = true
    latestShare?.copy()?.let { sendEventWhenReady(it) }
  }

  @ReactMethod
  fun removeListeners(count: Int) {
    hasListeners = false
  }

  override fun onHostResume() {
    latestShare?.copy()?.let { sendEventWhenReady(it) }
  }

  override fun onHostPause() = Unit

  override fun onHostDestroy() = Unit

  private fun parseShareIntent(intent: Intent, isInitial: Boolean): WritableMap? {
    val action = intent.action ?: return null
    if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
      return null
    }

    val mimeType = intent.type ?: "*/*"
    val files = Arguments.createArray()
    val text = intent.getStringExtra(Intent.EXTRA_TEXT)
    val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
    val title = intent.getStringExtra(Intent.EXTRA_TITLE)

    collectUris(intent).forEach { uri ->
      grantReadPermission(uri)
      files.pushMap(uriToFileMap(uri, mimeType))
    }

    if (text.isNullOrBlank() && files.size() == 0) {
      return null
    }

    return Arguments.createMap().apply {
      if (!text.isNullOrBlank()) putString("text", text)
      if (!subject.isNullOrBlank()) putString("subject", subject)
      if (!title.isNullOrBlank()) putString("title", title)
      putString("mimeType", mimeType)
      putArray("files", files)
      putBoolean("isInitial", isInitial)
      putDouble("receivedAt", System.currentTimeMillis().toDouble())
      extractWebUrl(text)?.let { putString("webUrl", it) }
    }
  }

  private fun collectUris(intent: Intent): List<Uri> {
    val uris = LinkedHashSet<Uri>()
    val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
    if (stream != null) uris.add(stream)

    val streams = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
    streams?.forEach { uri -> if (uri != null) uris.add(uri) }

    collectClipData(intent.clipData, uris)
    intent.data?.let { uris.add(it) }
    return uris.toList()
  }

  private fun collectClipData(clipData: ClipData?, uris: MutableSet<Uri>) {
    if (clipData == null) return
    for (index in 0 until clipData.itemCount) {
      clipData.getItemAt(index)?.uri?.let { uris.add(it) }
    }
  }

  private fun uriToFileMap(uri: Uri, fallbackMimeType: String): WritableMap {
    val resolver = reactContext.contentResolver
    val mimeType = resolver.getType(uri) ?: fallbackMimeType
    val metadata = queryMetadata(resolver, uri)

    return Arguments.createMap().apply {
      putString("uri", uri.toString())
      putString("type", classifyMimeType(mimeType))
      putString("mimeType", mimeType)
      metadata.name?.let { putString("fileName", it) }
      metadata.name?.let { putString("name", it) }
      metadata.size?.let { putDouble("size", it.toDouble()) }
      metadata.dateTaken?.let { putDouble("dateTaken", it.toDouble()) }
      putString("originalUri", uri.toString())
    }
  }

  private fun queryMetadata(resolver: ContentResolver, uri: Uri): FileMetadata {
    if (uri.scheme == ContentResolver.SCHEME_FILE) {
      val path = uri.path ?: return FileMetadata(null, null, null)
      val file = java.io.File(path)
      return FileMetadata(file.name, file.takeIf { it.exists() }?.length(), file.takeIf { it.exists() }?.lastModified())
    }

    var cursor: Cursor? = null
    return try {
      cursor = resolver.query(
        uri,
        arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE, MediaStore.MediaColumns.DATE_TAKEN),
        null,
        null,
        null
      )
      if (cursor != null && cursor.moveToFirst()) {
        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
        val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
        val dateTakenIndex = cursor.getColumnIndex(MediaStore.MediaColumns.DATE_TAKEN)
        FileMetadata(
          name = if (nameIndex >= 0) cursor.getString(nameIndex) else null,
          size = if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) cursor.getLong(sizeIndex) else null,
          dateTaken = if (dateTakenIndex >= 0 && !cursor.isNull(dateTakenIndex)) cursor.getLong(dateTakenIndex) else null
        )
      } else {
        FileMetadata(uri.lastPathSegment, null, null)
      }
    } catch (_: Exception) {
      FileMetadata(uri.lastPathSegment, null, null)
    } finally {
      cursor?.close()
    }
  }

  private fun grantReadPermission(uri: Uri) {
    try {
      val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
      reactContext.grantUriPermission(reactContext.packageName, uri, flags)
      reactContext.contentResolver.takePersistableUriPermission(uri, flags)
    } catch (_: Exception) {
      // Many providers do not support persisted grants. The temporary share grant is still valid.
    }
  }

  private fun sendEventWhenReady(payload: WritableMap, attempt: Int = 0) {
    if (!hasListeners && attempt < MAX_DELIVERY_ATTEMPTS) {
      mainHandler.postDelayed({ sendEventWhenReady(payload.copy(), attempt + 1) }, DELIVERY_RETRY_MS)
      return
    }

    if (!reactContext.hasActiveCatalystInstance()) {
      if (attempt < MAX_DELIVERY_ATTEMPTS) {
        mainHandler.postDelayed({ sendEventWhenReady(payload.copy(), attempt + 1) }, DELIVERY_RETRY_MS)
      }
      return
    }

    reactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(EVENT_NAME, payload)
  }

  private fun WritableMap.copy(): WritableMap = Arguments.makeNativeMap(this.toHashMap())

  private data class FileMetadata(val name: String?, val size: Long?, val dateTaken: Long?)

  companion object {
    const val NAME = "AdvancedShareIntent"
    private const val EVENT_NAME = "AdvancedShareIntentReceived"
    private const val MAX_DELIVERY_ATTEMPTS = 10
    private const val DELIVERY_RETRY_MS = 500L

    fun classifyMimeType(mimeType: String?): String {
      val value = mimeType?.lowercase() ?: return "unknown"
      return when {
        value.startsWith("image/") -> "image"
        value.startsWith("video/") -> "video"
        value.startsWith("text/") -> "text"
        value == "text/plain" -> "text"
        else -> "document"
      }
    }

    private fun extractWebUrl(text: String?): String? {
      if (text.isNullOrBlank()) return null
      return Regex("""https?://\S+""").find(text)?.value
    }
  }
}
