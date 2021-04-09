package com.sogeti.mlcameracapture

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.*
import android.hardware.camera2.*
import android.media.Image
import android.media.ImageReader
import android.net.Uri
import android.os.*
import android.provider.Settings
import androidx.appcompat.app.AppCompatActivity
import android.text.Editable
import android.text.TextWatcher
import android.util.Size
import android.view.*
import android.widget.*
import com.sogeti.mlcameracapture.Utilities.Async
import com.sogeti.mlcameracapture.Utilities.CompareSizesByArea
import com.sogeti.mlcameracapture.Utilities.Preferences
import java.io.*
import java.util.*
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class MainActivity : AppCompatActivity() {

    private val permissions = arrayOf(Manifest.permission.CAMERA)

    private var camera: String = ""
    private var previewSize: Size = Size(0, 0)
    private val cameraOpenCloseLock = Semaphore(1)
    private var cameraDevice: CameraDevice? = null
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private lateinit var textureView: TextureView
    private lateinit var editText: EditText
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var previewRequestBuilder: CaptureRequest.Builder? = null
    private var picturesToCapture: AtomicInteger = AtomicInteger(0)
    private var sensorOrientation: Int = 0
    private var showsCropSquare = false
    private lateinit var cropSquare: View

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        cropSquare = findViewById(R.id.cropSquare)
        textureView = findViewById(R.id.cameraView)
        findViewById<ImageView>(R.id.cameraButton).setOnClickListener { cameraButtonPressed(it) }
        findViewById<ImageView>(R.id.moreButton).setOnClickListener { openDropDown(it) }
        editText = findViewById(R.id.categoryEditText)
        editText.addTextChangedListener(textWatcher)
        editText.setText(Preferences.CurrentCategory.getString(this))

        val askPermissions = permissions.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (askPermissions.isNotEmpty()) { requestPermissions(askPermissions.toTypedArray(), 0) }
    }

    override fun onResume() {
        super.onResume()

        startBackgroundThread()

        if (textureView.isAvailable) startCameraSession(Size(textureView.width, textureView.height))
        textureView.surfaceTextureListener = surfaceTextureListener

        toggleCropSquare(Preferences.CropSquare.getBool(this))

        recalculateCount()
    }

    override fun onPause() {
        stopCameraSession()
        stopBackgroundThread()
        super.onPause()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            23 ->  { deleteZip(); stopLoading() }
            else -> super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun cameraButtonPressed(view: View) {
        picturesToCapture.incrementAndGet()

        view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY, HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING)
    }

    private fun openDropDown(sender: View) {
        val adapter = ArrayAdapter(this, R.layout.drowdown_item, mutableListOf(resources.getString(R.string.cropSquare), resources.getString(R.string.shareImages), resources.getString(R.string.deleteFiles)))
        val popupList = ListPopupWindow(this)
        popupList.anchorView = sender
        popupList.setDropDownGravity(Gravity.END)
        popupList.width = 400
        popupList.height = ListPopupWindow.WRAP_CONTENT
        popupList.setAdapter(adapter)
        popupList.setOnItemClickListener { _, _, i, _ ->
            when (i) {
                0 -> toggleCropSquare()
                1 -> shareImages()
                2 -> deleteFiles()
            }
            popupList.dismiss()
        }
        popupList.show()
    }

    private fun toggleCropSquare(boolean: Boolean? = null) {
        showsCropSquare = boolean ?: !showsCropSquare
        findViewById<View>(R.id.cropSquare)?.alpha = if (showsCropSquare) 1f else 0f
        Preferences.CropSquare.set(this, showsCropSquare)
    }

    private fun startLoading() {
        if (!Looper.getMainLooper().isCurrentThread) { runOnUiThread { startLoading() }; return }
        //TODO: implement
    }

    private fun stopLoading() {
        if (!Looper.getMainLooper().isCurrentThread) { runOnUiThread { stopLoading() }; return }
        //TODO: implement
    }

    private fun shareImages() {

        startLoading()

        Async {
            createZip()
            shareZip()
        }

    }

    private fun zipfile(): File? {
        val externalDir = getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS).toString()
        return File(externalDir + "/" + resources.getString(R.string.imagesFilename) + ".zip")
    }


    private fun createZip() {
        val outfile = zipfile() ?: return
        val dir = homeDir() ?: return
        val rootList = dir.listFiles() ?: return
        val list: List<File> = rootList.flatMap { if (it.isDirectory) (it.listFiles() ?: emptyArray<File>()).asList() else listOf(it) }

        ZipOutputStream(BufferedOutputStream(FileOutputStream(outfile))).use { output ->
            for (file in list) {
                FileInputStream(file).use { input ->
                    BufferedInputStream(input).use { buffer ->
                        val name = file.toString().replace(dir.toString(), "")
                        val entry = ZipEntry(name)
                        output.putNextEntry(entry)
                        buffer.copyTo(output, 1024)
                    }
                }
            }
        }
    }

    private fun shareZip() {
        val outfile = zipfile() ?: return
        val targetShareIntents = ArrayList<Intent>()
        val intent = Intent()
        intent.action = Intent.ACTION_SEND
        intent.type = "application/zip"
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.putExtra(Intent.EXTRA_STREAM, Uri.fromFile(outfile))

        val chooserIntent = Intent.createChooser(intent, resources.getString(R.string.shareImages))
        chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, targetShareIntents.toTypedArray<Parcelable>())

        val builder = StrictMode.VmPolicy.Builder()
        StrictMode.setVmPolicy(builder.build())

        startActivityForResult(chooserIntent, 29)
    }

    private fun deleteZip() {
        val outfile = zipfile() ?: return
        outfile.delete()
    }

    private fun deleteFiles() {
        //TODO: Ask first alert
        val dir = currentDir() ?: return
        dir.deleteRecursively()
        recalculateCount()
    }


    //MARK: Camera

    private fun createCameraPreviewSession() {
        val texture = textureView.surfaceTexture
        texture.setDefaultBufferSize(previewSize.width, previewSize.height)

        val surface = Surface(texture)
        previewRequestBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
        previewRequestBuilder?.addTarget(surface)

        cameraDevice?.createCaptureSession(listOf(surface, imageReader?.surface), captureStateCallback, null)
    }

    private fun stopCameraSession() {
        cameraOpenCloseLock.acquire()
        captureSession?.close()
        captureSession = null
        cameraDevice?.close()
        cameraDevice = null
        imageReader?.close()
        imageReader = null
        cameraOpenCloseLock.release()
    }

    private fun startCameraSession(surfaceSize: Size) {
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) return

        val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        if (manager.cameraIdList.isEmpty()) return

        camera = getCameraID(manager.cameraIdList, manager) ?: return
//        val largest = getLargestImageSize(manager) ?: return

        val w = 299 * textureView.width / cropSquare.width
        val h = 299 * textureView.height / cropSquare.height

        val outputSize = getOptimalSize(manager, Size(w, h)) ?: return

        imageReader = ImageReader.newInstance(outputSize.width, outputSize.height, ImageFormat.JPEG, 1)
        imageReader?.apply { setOnImageAvailableListener(onImageAvailableListener, backgroundHandler) }

        previewSize = getOptimalSize(manager, surfaceSize) ?: return

//        textureView.setAspectRatio(previewSize.height, previewSize.width)

        configureTransform(surfaceSize)

        if (!cameraOpenCloseLock.tryAcquire(2500, TimeUnit.MILLISECONDS)) return

        manager.openCamera(camera, deviceStateCallback, backgroundHandler)

    }

    private fun configureTransform(surfaceSize: Size) {
        val rotation = windowManager?.defaultDisplay?.rotation ?: Surface.ROTATION_0
        val matrix = Matrix()
        val viewRect = RectF(0f, 0f, surfaceSize.width.toFloat(), surfaceSize.height.toFloat())
//        val bufferRect = RectF(0f, 0f, previewSize.height.toFloat(), previewSize.width.toFloat())
        val centerX = viewRect.centerX()
        val centerY = viewRect.centerY()
        if (Surface.ROTATION_180 == rotation) matrix.postRotate(180f, centerX, centerY)
        textureView.setTransform(matrix)
    }

    private fun getOptimalSize(manager: CameraManager, surfaceSize: Size): Size? {
        val characteristics = manager.getCameraCharacteristics(camera)

        sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
        val swappedDimensions = (sensorOrientation == 90 || sensorOrientation == 270)

        val displaySize = Point()
        windowManager?.defaultDisplay?.getSize(displaySize)

        val rotatedPreviewWidth = if (swappedDimensions) surfaceSize.height else surfaceSize.width
        val rotatedPreviewHeight = if (swappedDimensions) surfaceSize.width else surfaceSize.height
        var maxPreviewWidth = if (swappedDimensions) displaySize.y else displaySize.x
        var maxPreviewHeight = if (swappedDimensions) displaySize.x else displaySize.y

        if (maxPreviewWidth > 1920) maxPreviewWidth = 1920
        if (maxPreviewHeight > 1080) maxPreviewHeight = 1080

        val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP) ?: return null
        val sizes = map.getOutputSizes(SurfaceTexture::class.java)
            .filter { x -> (x.width <= maxPreviewWidth && x.height <= maxPreviewHeight) }
        val bigEnough = ArrayList<Size>()
        val notBigEnough = ArrayList<Size>()
        sizes.forEach { x -> if (x.width >= rotatedPreviewWidth && x.height >= rotatedPreviewHeight) bigEnough.add(x) else notBigEnough.add(x) }

        if (bigEnough.isNotEmpty()) return Collections.min(bigEnough, CompareSizesByArea())
        if (notBigEnough.isNotEmpty()) return Collections.max(notBigEnough, CompareSizesByArea())
        return null
    }

    private fun getLargestImageSize(manager: CameraManager): Size? {
        val characteristics = manager.getCameraCharacteristics(camera)
        val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP) ?: return null
        val largest = Collections.max(listOf(*map.getOutputSizes(ImageFormat.JPEG)), CompareSizesByArea())
        return largest
    }

    private fun getCameraID(list: Array<String>, manager: CameraManager): String? {
        for (id in list) {
            val characteristics = manager.getCameraCharacteristics(id)
            val cameraDirection = characteristics.get(CameraCharacteristics.LENS_FACING)
            if (cameraDirection == null || cameraDirection != CameraCharacteristics.LENS_FACING_BACK) continue
            if (characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP) == null) continue

            return id
        }

        return null
    }

    private fun captureStillImage() {
        val surface = imageReader?.surface ?: return
        val rotation = windowManager?.defaultDisplay?.rotation ?: 0
        val captureBuilder = cameraDevice?.createCaptureRequest(
            CameraDevice.TEMPLATE_STILL_CAPTURE)?.apply {
            addTarget(surface)

            set(CaptureRequest.JPEG_ORIENTATION, (rotation + sensorOrientation) % 360)


            set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
        }

        val request = captureBuilder?.build() ?: return
        captureSession?.apply { capture(request, captureCallback, null) }
    }

    private fun saveImage(bytes: ByteArray) {
        val dir  = currentDir() ?: return
        if (!dir.exists()) dir.mkdirs()
        val filename = UUID.randomUUID().toString() + ".jpg"
        val file = File(dir.toString(), filename)

        FileOutputStream(file).use { it.write(bytes) }

        runOnUiThread { recalculateCount() }
    }

    private fun shouldCropImage(image: Image): ByteArray {

        val buffer = image.planes[0].buffer
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)

        if (!showsCropSquare) return bytes

        var bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, null)

        val matrix = Matrix()
        if (bitmap.height < bitmap.width)  matrix.postRotate(90f)

        bitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)

        val cropWidth = cropSquare.width.toFloat()
        val cropHeight = cropSquare.height.toFloat()
        val textureWidth = textureView.width.toFloat()
        val textureHeight = textureView.height.toFloat()
        val imageWidth = bitmap.width.toFloat()
        val imageHeight = bitmap.height.toFloat()


        val xPercentage = cropWidth / textureWidth
        val yPercentage = cropHeight / textureHeight

        val imageAspect = imageWidth / imageHeight
        val screenAspect = textureWidth / textureHeight

        val w = if (screenAspect > imageAspect) imageWidth * xPercentage else imageHeight * yPercentage
        val h = w

        val x = imageWidth * 0.5 - w * 0.5
        val y = imageHeight * 0.5 - h * 0.5

        bitmap = Bitmap.createBitmap(bitmap, x.toInt(), y.toInt(), w.toInt(), h.toInt())

        val cropBytes = ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.JPEG, 100, it)
            it.toByteArray()
        }

        return cropBytes

    }

    private var captureStateCallback = object : CameraCaptureSession.StateCallback() {
        override fun onConfigureFailed(cameraCaptureSession: CameraCaptureSession) {}

        override fun onConfigured(cameraCaptureSession: CameraCaptureSession) {
            if (cameraDevice == null) return
            captureSession = cameraCaptureSession

            previewRequestBuilder?.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)

            val previewRequest = previewRequestBuilder?.build() ?: return
            captureSession?.setRepeatingRequest(previewRequest, captureCallback, backgroundHandler)

        }
    }

    private val deviceStateCallback = object : CameraDevice.StateCallback() {

        override fun onOpened(cameraDevice: CameraDevice) {
            cameraOpenCloseLock.release()
            this@MainActivity.cameraDevice = cameraDevice
            createCameraPreviewSession()
        }

        override fun onDisconnected(cameraDevice: CameraDevice) {
            cameraOpenCloseLock.release()
            cameraDevice.close()
            this@MainActivity.cameraDevice = null
        }

        override fun onError(cameraDevice: CameraDevice, error: Int) {
            onDisconnected(cameraDevice)
        }
    }

    private val captureCallback = object : CameraCaptureSession.CaptureCallback() {

        private fun process(result: CaptureResult) {
            if (picturesToCapture.get() > 0) {
                captureStillImage()
                picturesToCapture.decrementAndGet()
            }

        }

        override fun onCaptureProgressed(session: CameraCaptureSession, request: CaptureRequest, partialResult: CaptureResult) {
            process(partialResult)
        }

        override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
            process(result)
        }

    }

    private val onImageAvailableListener = ImageReader.OnImageAvailableListener {
        backgroundHandler?.post {

            val bytes = it.acquireNextImage().use { shouldCropImage(it) }
//            if (showsCropSquare) { bytes = cropImage(bytes) }
            saveImage(bytes)

        }
    }

    //MARK: SurfaceTexture

    private val surfaceTextureListener = object : TextureView.SurfaceTextureListener {

        override fun onSurfaceTextureAvailable(texture: SurfaceTexture, width: Int, height: Int) {
            startCameraSession(Size(width, height))
        }

        override fun onSurfaceTextureSizeChanged(texture: SurfaceTexture, width: Int, height: Int) {
            configureTransform(Size(width, height))
        }

        override fun onSurfaceTextureDestroyed(texture: SurfaceTexture) = true
        override fun onSurfaceTextureUpdated(texture: SurfaceTexture) = Unit
    }
    //MARK: Background

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        val looper = backgroundThread?.looper ?: return
        backgroundHandler = Handler(looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        backgroundThread?.join()
        backgroundThread = null
        backgroundHandler = null

    }

    //MARK: EditText

    val textWatcher = object : TextWatcher {
        override fun afterTextChanged(p0: Editable?) { }

        override fun beforeTextChanged(p0: CharSequence?, p1: Int, p2: Int, p3: Int) { }

        override fun onTextChanged(p0: CharSequence?, p1: Int, p2: Int, p3: Int) {

            val regex = Regex("\\W+")
            val newText = editText.text.replace(regex, "")
            if (editText.text.toString() != newText) {
                val index = editText.selectionStart
                editText.setText(newText)
                editText.setSelection(index-1)
            }
            Preferences.CurrentCategory.set(this@MainActivity, newText)
            recalculateCount()
        }

    }

    private fun homeDir(): File? {
        val homeDir = filesDir ?: return null
        val dir = "$homeDir/CVFolder"
        return File(dir)
    }

    private fun currentDir(): File? {
        val homeDir = homeDir() ?: return null
        val dir = homeDir.toString() + "/" + editText.text
        return File(dir)
    }


    private fun recalculateCount() {
        val dir = currentDir() ?: return
        val count = dir.list()?.size ?: 0
        findViewById<TextView>(R.id.textView)?.setText(resources.getString(R.string.images, count))
    }

    //MARK: PermissionActivity Result

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)


        for (permission in permissions) {
            if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) continue
            if (!shouldShowRequestPermissionRationale(permission)) continue
            val intent = Intent()
            intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
            intent.data = Uri.fromParts("package", packageName, null)
            startActivity(intent)
            break
        }
    }
}
