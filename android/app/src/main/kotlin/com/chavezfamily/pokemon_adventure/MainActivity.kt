package com.chavezfamily.pokemon_adventure

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updateChannel = "com.chavezfamily.pokemon_adventure/app_updates"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            updateChannel,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getInstalledAppInfo" -> {
                        val packageInfo = packageManager.getPackageInfo(packageName, 0)
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            packageInfo.versionCode.toLong()
                        }
                        result.success(
                            mapOf(
                                "packageName" to packageName,
                                "versionCode" to versionCode,
                                "versionName" to (packageInfo.versionName ?: ""),
                            ),
                        )
                    }
                    "canRequestInstall" -> {
                        val allowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                        result.success(allowed)
                    }
                    "openInstallPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            )
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "launchInstaller" -> {
                        val requestedPath = call.argument<String>("apkPath")
                            ?: throw IllegalArgumentException("apkPath is required")
                        launchInstaller(requestedPath)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error(
                    "APP_UPDATE_ERROR",
                    error.message ?: "Android could not prepare the update.",
                    null,
                )
            }
        }
    }

    private fun launchInstaller(requestedPath: String) {
        val updatesDirectory = File(filesDir, "updates").canonicalFile
        val apk = File(requestedPath).canonicalFile
        if (
            apk.parentFile != updatesDirectory ||
            apk.extension.lowercase() != "apk" ||
            !apk.isFile
        ) {
            throw SecurityException("Only verified APKs in app update storage may be installed.")
        }
        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.update_files",
            apk,
        )
        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = apkUri
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            putExtra(Intent.EXTRA_RETURN_RESULT, false)
        }
        startActivity(intent)
    }
}
