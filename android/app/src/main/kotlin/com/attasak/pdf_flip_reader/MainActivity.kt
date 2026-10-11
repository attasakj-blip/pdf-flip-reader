package com.attasak.pdf_flip_reader

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * File work Flutter plugins don't cover: opening a PDF with lasting write
 * access (so a signed copy can replace it), creating files and folders
 * through the system picker, and putting an image on the clipboard.
 */
class MainActivity : FlutterActivity() {
    private val openRequest = 4101
    private val createRequest = 4102
    private val treeRequest = 4103

    private var pending: MethodChannel.Result? = null
    private var pendingCall: MethodCall? = null
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pdf_flip_reader/files")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "openPdf" -> startPicker(call, result, openRequest,
                            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/pdf"
                                addFlags(persistFlags)
                            })
                        "createPdf" -> startPicker(call, result, createRequest,
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/pdf"
                                putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                                addFlags(persistFlags)
                            })
                        "createInNewFolder" -> startPicker(call, result, treeRequest,
                            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply { addFlags(persistFlags) })
                        "write" -> background(result) {
                            val uri = Uri.parse(call.argument<String>("uri"))
                            val out = try {
                                contentResolver.openOutputStream(uri, "wt")
                            } catch (e: Exception) {
                                contentResolver.openOutputStream(uri, "w")
                            } ?: throw IllegalStateException("cannot write $uri")
                            out.use { o -> File(call.argument<String>("path")!!).inputStream().use { it.copyTo(o) } }
                            null
                        }
                        "canWrite" -> result.success(contentResolver.persistedUriPermissions.any {
                            it.uri.toString() == call.argument<String>("uri") && it.isWritePermission
                        })
                        "copyImage" -> {
                            val file = File(call.argument<String>("path")!!)
                            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                            val clip = ClipData.newUri(contentResolver, "PDF page", uri)
                            (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(clip)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("files", e.message, null)
                }
            }
    }

    private val persistFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION

    private fun startPicker(call: MethodCall, result: MethodChannel.Result, code: Int, intent: Intent) {
        pending?.success(null) // an older picker that never answered
        pending = result
        pendingCall = call
        startActivityForResult(intent, code)
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            try {
                val v = work()
                main.post { result.success(v) }
            } catch (e: Exception) {
                main.post { result.error("files", e.message, null) }
            }
        }.start()
    }

    private fun keep(uri: Uri) {
        try {
            contentResolver.takePersistableUriPermission(uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        } catch (e: Exception) {
            try {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: Exception) {
            }
        }
    }

    private fun nameOf(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        }
    } catch (_: Exception) {
        null
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != openRequest && requestCode != createRequest && requestCode != treeRequest) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pending ?: return
        val call = pendingCall!!
        pending = null
        pendingCall = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        keep(uri)
        when (requestCode) {
            // Copy the picked PDF into the app, so it opens fast and stays available.
            openRequest -> background(result) {
                val name = nameOf(uri) ?: "document.pdf"
                val dest = File(call.argument<String>("dir")!!, "${System.currentTimeMillis()}_$name")
                contentResolver.openInputStream(uri)!!.use { i -> dest.outputStream().use { i.copyTo(it) } }
                mapOf("uri" to uri.toString(), "name" to name, "path" to dest.path)
            }
            createRequest -> result.success(mapOf("uri" to uri.toString(), "name" to (nameOf(uri) ?: "")))
            treeRequest -> background(result) {
                val parent = DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
                val folder = DocumentsContract.createDocument(contentResolver, parent,
                    DocumentsContract.Document.MIME_TYPE_DIR, call.argument<String>("folder")!!)
                    ?: throw IllegalStateException("cannot create folder")
                val file = DocumentsContract.createDocument(contentResolver, folder,
                    "application/pdf", call.argument<String>("name")!!)
                    ?: throw IllegalStateException("cannot create file")
                mapOf("uri" to file.toString(), "name" to (nameOf(file) ?: ""))
            }
        }
    }
}
