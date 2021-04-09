//
//  ViewController.swift
//  MLCameraCapture
//
//  Created by Wilhelm Thieme on 10/09/2019.
//  Copyright © 2019 Sogeti Nederland B.V. All rights reserved.
//

import AVFoundation
import UIKit
import Zip

fileprivate let videoQueue =  DispatchQueue(label: "videoBuffer")
fileprivate let analyzeQueue = DispatchQueue(label: "analyzeQueue")
fileprivate let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("folder")

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, UITextFieldDelegate {
    
    private let photoView = UIView()
    private let scannerSquare = UIView()
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isCapturesSessionBuilt = false
    
    private let moreButton = UIButton()
    private let statusBarFrame = UIView()
    private let cameraButton = UIButton()
    
    private let textField = UITextField()
    private let numberLabel = UILabel()
    
    private var showScannerSquare = Defaults.kCropSquare.bool { didSet { Defaults.kCropSquare.set(showScannerSquare) } }
    
    private var tapGesture: UITapGestureRecognizer!
    
    private var category = Defaults.kCurrentCategory.string { didSet { Defaults.kCurrentCategory.set(category) } }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "background")
        
        photoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(photoView)
        photoView.topAnchor.constraint(equalTo: view.topAnchor).activated()
        photoView.bottomAnchor.constraint(equalTo: view.bottomAnchor).activated()
        photoView.leadingAnchor.constraint(equalTo: view.leadingAnchor).activated()
        photoView.trailingAnchor.constraint(equalTo: view.trailingAnchor).activated()
        
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        moreButton.setImage(UIImage(named: "MoreIcon"), for: .normal)
        moreButton.tintColor = UIColor(named: "tint")
        moreButton.addTarget(self, action: #selector(plusButtonClicked), for: .touchUpInside)
        view.addSubview(moreButton)
        moreButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: .padding).activated()
        moreButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -.padding).activated()
        moreButton.setContentHuggingPriority(.required, for: .vertical)
        moreButton.setContentHuggingPriority(.required, for: .horizontal)
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        textField.delegate = self
        textField.placeholder = LocalizedString("categoryPlaceholder")
        textField.text = category
        textField.textColor = UIColor(named: "text")
        view.addSubview(textField)
        textField.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: .padding).activated()
        textField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: .padding).activated()
        textField.bottomAnchor.constraint(equalTo: moreButton.bottomAnchor).activated()
        
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.textColor = UIColor(named: "disabled")
        view.addSubview(numberLabel)
        numberLabel.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: .padding).activated()
        numberLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: .padding).activated()
        numberLabel.bottomAnchor.constraint(equalTo: moreButton.bottomAnchor).activated()
        numberLabel.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -.padding).activated()
        numberLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        statusBarFrame.backgroundColor = UIColor(named: "background")?.withAlphaComponent(0.7)
        statusBarFrame.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(statusBarFrame, belowSubview: moreButton)
        statusBarFrame.leadingAnchor.constraint(equalTo: view.leadingAnchor).activated()
        statusBarFrame.trailingAnchor.constraint(equalTo: view.trailingAnchor).activated()
        statusBarFrame.topAnchor.constraint(equalTo: view.topAnchor).activated()
        statusBarFrame.bottomAnchor.constraint(equalTo: moreButton.bottomAnchor, constant: .padding).activated()
        
        scannerSquare.translatesAutoresizingMaskIntoConstraints = false
        scannerSquare.layer.borderColor = UIColor.blue.withAlphaComponent(0.5).cgColor
        scannerSquare.layer.borderWidth = 2
        scannerSquare.isHidden = !showScannerSquare
        view.addSubview(scannerSquare)
        scannerSquare.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5).activated()
        scannerSquare.heightAnchor.constraint(equalTo: scannerSquare.widthAnchor).activated()
        scannerSquare.centerXAnchor.constraint(equalTo: view.centerXAnchor).activated()
        scannerSquare.centerYAnchor.constraint(equalTo: view.centerYAnchor).activated()
        
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        cameraButton.setImage(UIImage(named: "CameraIcon"), for: .normal)
        cameraButton.tintColor = UIColor(named: "tint")
        cameraButton.addTarget(self, action: #selector(cameraButtonClicked), for: .touchUpInside)
        view.addSubview(cameraButton)
        cameraButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -.padding).activated()
        cameraButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).activated()
        
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        
        recalculateCount()
    }
    
    @objc private func shouldBuildCaptureSession() {
        AVCaptureDevice.requestAccess(for: .video) { (granted) in
            DispatchQueue.main.async {
                granted ? self.buildCaptureSession() : self.showAuthorizationAlert()
            }
        }
//        Permissions.request([.camera]) { (granted) in
//
//        }
    }
    
    private func buildCaptureSession() {
        defer { captureSession?.startRunning() }
        if isCapturesSessionBuilt { return }
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        captureSession?.addInput(input)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        photoView.layer.addSublayer(previewLayer!)
        
        let bufferOutput = AVCaptureVideoDataOutput()
        bufferOutput.setSampleBufferDelegate(self, queue: videoQueue)
        bufferOutput.alwaysDiscardsLateVideoFrames = true
        
        captureSession?.addOutput(bufferOutput)
        captureSession?.commitConfiguration()
        isCapturesSessionBuilt = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        shouldBuildCaptureSession()
        NotificationCenter.default.addObserver(self, selector: #selector(shouldBuildCaptureSession), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        captureSession?.stopRunning()
    }
    
    private func showAuthorizationAlert() {
        AlertController.showAlert(on: self, with: LocalizedString("cameraAuthrorisationAlertMessage"), and: [.ok, .settings])
    }
    
    var xPercentage: CGFloat = 0
    var yPercentage: CGFloat = 0
    var screenAspect: CGFloat = 0
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        previewLayer?.frame = view.bounds
        
        let square = view.convert(scannerSquare.frame, to: photoView)
        xPercentage = square.width / photoView.frame.width
        yPercentage = square.height / photoView.frame.height
        
        screenAspect = photoView.frame.width / photoView.frame.height
    }
    
    @objc private func plusButtonClicked(sender: UIButton) {
        let frame = view.convert(sender.frame, to: nil)
        let controller = DropdownController(anchor: CGPoint(x: frame.midX, y: frame.maxY), anchorLocation: .topRight)
        
        //TODO: Localize
        controller.addRow(title: LocalizedString("squareTitle"), checked: showScannerSquare) {
            self.showScannerSquare = !self.showScannerSquare
            self.scannerSquare.isHidden = !self.showScannerSquare
        }
        
        controller.addRow(title: LocalizedString("shareTitle")) { self.zipAndShare() }
        controller.addRow(title: LocalizedString("resetTitle")) {
            let yes = AlertController.ActionType.custom(title: LocalizedString("yes"), style: .destructive, action: self.deleteFiles)
            let no = AlertController.ActionType.custom(title: LocalizedString("no"), style: .cancel, action: nil)
            DispatchQueue.main.async { AlertController.showAlert(on: self, with: LocalizedString("resetWarning"), and: [no, yes]) }
        }
        
        present(controller, animated: true, completion: nil)
    }
    
    private func zipAndShare() {
        //start loading
        startLoading()
        DispatchQueue.global().async {
            guard let folders = try? FileIO.allFileNames(at: dir) else { self.stopLoading(); return }
            guard let url = try? Zip.quickZipFiles(folders, fileName: LocalizedString("zipFileName")) else { self.stopLoading(); return }
            let shareController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            DispatchQueue.main.async { self.present(shareController, animated: true, completion: { self.stopLoading() }) }
        }
    }
    
    private func deleteFiles() {
        try? FileIO.delete(dir)
        recalculateCount()
    }
    
    private func startLoading() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.startLoading() }; return}
        //TODO: implement
    }
    
    private func stopLoading() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.stopLoading() }; return}
        //TODO: implement
    }
    
    @objc private func cameraButtonClicked() {
        picsToTake.increment()
        UIImpactFeedbackGenerator().impactOccurred()
    }
    
    //MARK: Camera
    
    private var picsToTake = AtomicInt()
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard picsToTake.value > 0 else { return }
        picsToTake.decrement()
        
        analyzeQueue.async {
            var ci = CIImage(cvImageBuffer: buffer).oriented(.right)
            if self.showScannerSquare { ci = self.cropImage(ci) }
            
            let context = CIContext()
            guard let data = context.jpegRepresentation(of: ci, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, options: [:]) else { return } // TODO: UseWrite Jpgerepresentation
            
            let filename = "\(UUID().uuidString).jpg"
            let url = dir.appendingPathComponent(self.category).appendingPathComponent(filename)
            
            try? FileIO.save(data: data, to: url)
            
            self.recalculateCount()
        }
    }
    
    func cropImage(_ image: CIImage) -> CIImage {
        let imageAspect = image.extent.width / image.extent.height
        
        //TODO: creates a border on the image
        
        let width = screenAspect > imageAspect ? image.extent.width * xPercentage : image.extent.height * yPercentage
        let height = width
        
        let x = image.extent.width * 0.5 - width * 0.5
        let y = image.extent.height * 0.5 - height * 0.5
        
        let rect = CGRect(x: x, y: y, width: width, height: height)
        
        return image.cropped(to: rect)
    }
    
    
    //MARK: Keyboard
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        dismissKeyboard()
        return false
    }
    
    @objc private func textFieldChanged() {
        category = textField.text?.filenameSafe ?? "dump"
        recalculateCount()
    }
    
    @objc private func dismissKeyboard() {
        textField.resignFirstResponder()
        recalculateCount()
    }
    
    private func recalculateCount() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.recalculateCount() }; return }
        let url = dir.appendingPathComponent(category)
        guard let count = try? FileIO.allFileNames(at: url).count else { return }
        numberLabel.text = LocalizedString("numImages", "\(count)")
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        view.removeGestureRecognizer(tapGesture)
    }
    
    
    //MARK: StatusBar in Dark Mode
    
    private var statusBarStyle: UIStatusBarStyle = .default {
        didSet { if statusBarStyle != oldValue { setNeedsStatusBarAppearanceUpdate() } }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle { return statusBarStyle }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        
        if #available(iOS 12.0, *) {
            statusBarStyle = traitCollection.userInterfaceStyle == .dark ? .lightContent : .default
        }
        
    }
}


