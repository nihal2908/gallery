package com.example.gallery

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import java.io.FileInputStream
import java.io.FileOutputStream
import javax.crypto.Cipher
import javax.crypto.CipherInputStream
import javax.crypto.CipherOutputStream
import javax.crypto.spec.SecretKeySpec
import javax.crypto.spec.IvParameterSpec
import java.security.SecureRandom
import android.util.Base64

class MainActivity: FlutterActivity() {

    private val CHANNEL = "file_crypto"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    "encryptFile" -> {
                        val inputPath = call.argument<String>("inputPath")!!
                        val outputPath = call.argument<String>("outputPath")!!
                        val keyBase64 = call.argument<String>("key")!!

                        Thread {
                            encryptFile(inputPath, outputPath, keyBase64)
                            runOnUiThread { result.success(null) }
                        }.start()
                    }

                    "decryptFile" -> {
                        val inputPath = call.argument<String>("inputPath")!!
                        val outputPath = call.argument<String>("outputPath")!!
                        val keyBase64 = call.argument<String>("key")!!

                        Thread {
                            decryptFile(inputPath, outputPath, keyBase64)
                            runOnUiThread { result.success(null) }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun encryptFile(inputPath: String, outputPath: String, keyBase64: String) {
        val keyBytes = Base64.decode(keyBase64, Base64.DEFAULT)
        val keySpec = SecretKeySpec(keyBytes, "AES")

        val cipher = Cipher.getInstance("AES/CTR/NoPadding")

        val iv = ByteArray(16)
        SecureRandom().nextBytes(iv)

        cipher.init(Cipher.ENCRYPT_MODE, keySpec, IvParameterSpec(iv))

        val inputStream = FileInputStream(inputPath)
        val outputStream = FileOutputStream(outputPath)

        outputStream.write(iv)

        val cipherStream = CipherOutputStream(outputStream, cipher)

        val buffer = ByteArray(1024 * 1024)

        var bytesRead: Int
        while (inputStream.read(buffer).also { bytesRead = it } != -1) {
            cipherStream.write(buffer, 0, bytesRead)
        }

        cipherStream.close()
        inputStream.close()
    }

    private fun decryptFile(inputPath: String, outputPath: String, keyBase64: String) {
        val keyBytes = Base64.decode(keyBase64, Base64.DEFAULT)
        val keySpec = SecretKeySpec(keyBytes, "AES")

        val inputStream = FileInputStream(inputPath)

        val iv = ByteArray(16)
        inputStream.read(iv)

        val cipher = Cipher.getInstance("AES/CTR/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, keySpec, IvParameterSpec(iv))

        val cipherInputStream = CipherInputStream(inputStream, cipher)
        val outputStream = FileOutputStream(outputPath)

        val buffer = ByteArray(1024 * 1024)

        var bytesRead: Int
        while (cipherInputStream.read(buffer).also { bytesRead = it } != -1) {
            outputStream.write(buffer, 0, bytesRead)
        }

        outputStream.close()
        cipherInputStream.close()
    }
}