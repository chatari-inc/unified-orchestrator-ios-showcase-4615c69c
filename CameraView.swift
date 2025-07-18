// filepath: CameraView.swift

import SwiftUI
import AVFoundation
import PhotosUI

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingGallery = false
    @State private var showingSettings = false
    @State private var capturedImage: UIImage?
    @State private var showingImagePreview = false
    @State private var flashMode: AVCaptureDevice.FlashMode = .auto
    @State private var showGrid = false
    @State private var timerDuration = 0
    @State private var zoomFactor: CGFloat = 1.0
    @State private var focusPoint: CGPoint = .zero
    @State private var showFocusIndicator = false
    @State private var isCapturing = false
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(
                session: cameraManager.session,
                focusPoint: $focusPoint,
                showFocusIndicator: $showFocusIndicator,
                onTap: handleTapToFocus,
                onPinch: handlePinchToZoom
            )
            .ignoresSafeArea()
            
            // Grid overlay
            if showGrid {
                gridOverlay
            }
            
            // Focus indicator
            if showFocusIndicator {
                focusIndicator
            }
            
            // Top controls
            VStack {
                topControls
                Spacer()
            }
            
            // Bottom controls
            VStack {
                Spacer()
                bottomControls
            }
            
            // Settings panel
            if showingSettings {
                settingsPanel
            }
        }
        .onAppear {
            requestPermissions()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showingGallery) {
            PhotoLibraryView(selectedImage: $capturedImage)
        }
        .sheet(isPresented: $showingImagePreview) {
            ImagePreviewView(image: $capturedImage)
        }
        .alert("Camera Permission", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionAlertMessage)
        }
    }
    
    private var topControls: some View {
        HStack {
            Button(action: { showingSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Button(action: toggleFlash) {
                Image(systemName: flashIconName)
                    .font(.title2)
                    .foregroundColor(flashMode == .off ? .gray : .white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    
    private var bottomControls: some View {
        HStack {
            // Gallery button
            Button(action: { showingGallery = true }) {
                if let thumbnail = cameraManager.galleryThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 2)
                        )
                } else {
                    Image(systemName: "photo.stack")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .accessibilityLabel("Photo Gallery")
            
            Spacer()
            
            // Capture button
            Button(action: capturePhoto) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 60, height: 60)
                    
                    if isCapturing {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 50, height: 50)
                    }
                }
                .scaleEffect(isCapturing ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isCapturing)
            }
            .accessibilityLabel("Capture Photo")
            .disabled(isCapturing)
            
            Spacer()
            
            // Camera switch button
            Button(action: switchCamera) {
                Image(systemName: "camera.rotate")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Switch Camera")
        }
        .padding()
    }
    
    private var gridOverlay: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                // Vertical lines
                path.move(to: CGPoint(x: width / 3, y: 0))
                path.addLine(to: CGPoint(x: width / 3, y: height))
                path.move(to: CGPoint(x: 2 * width / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * width / 3, y: height))
                
                // Horizontal lines
                path.move(to: CGPoint(x: 0, y: height / 3))
                path.addLine(to: CGPoint(x: width, y: height / 3))
                path.move(to: CGPoint(x: 0, y: 2 * height / 3))
                path.addLine(to: CGPoint(x: width, y: 2 * height / 3))
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
    
    private var focusIndicator: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .position(focusPoint)
            .animation(.easeInOut(duration: 0.3), value: focusPoint)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showFocusIndicator = false
                }
            }
    }
    
    private var settingsPanel: some View {
        VStack(spacing: 20) {
            Text("Camera Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 15) {
                // Flash mode
                VStack(alignment: .leading) {
                    Text("Flash")
                        .font(.headline)
                    Picker("Flash", selection: $flashMode) {
                        Text("Auto").tag(AVCaptureDevice.FlashMode.auto)
                        Text("On").tag(AVCaptureDevice.FlashMode.on)
                        Text("Off").tag(AVCaptureDevice.FlashMode.off)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: flashMode) { _ in
                        cameraManager.setFlashMode(flashMode)
                    }
                }
                
                // Grid toggle
                Toggle("Grid Lines", isOn: $showGrid)
                
                // Timer
                VStack(alignment: .leading) {
                    Text("Timer")
                        .font(.headline)
                    Picker("Timer", selection: $timerDuration) {
                        Text("Off").tag(0)
                        Text("3s").tag(3)
                        Text("10s").tag(10)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            
            Button("Done") {
                showingSettings = false
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 10)
        .padding()
    }
    
    private var flashIconName: String {
        switch flashMode {
        case .auto:
            return "bolt.badge.a"
        case .on:
            return "bolt"
        case .off:
            return "bolt.slash"
        @unknown default:
            return "bolt"
        }
    }
    
    private func requestPermissions() {
        cameraManager.requestCameraPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    cameraManager.setupCamera()
                } else {
                    permissionAlertMessage = "Camera access is required to take photos."
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func capturePhoto() {
        guard !isCapturing else { return }
        
        isCapturing = true
        
        if timerDuration > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(timerDuration)) {
                performCapture()
            }
        } else {
            performCapture()
        }
    }
    
    private func performCapture() {
        cameraManager.capturePhoto { image in
            DispatchQueue.main.async {
                if let image = image {
                    capturedImage = image
                    showingImagePreview = true
                }
                isCapturing = false
            }
        }
    }
    
    private func switchCamera() {
        cameraManager.switchCamera()
    }
    
    private func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .auto
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
        cameraManager.setFlashMode(flashMode)
    }
    
    private func handleTapToFocus(_ point: CGPoint) {
        focusPoint = point
        showFocusIndicator = true
        cameraManager.focusAt(point)
    }
    
    private func handlePinchToZoom(_ scale: CGFloat) {
        let newZoomFactor = min(max(zoomFactor * scale, 1.0), 10.0)
        zoomFactor = newZoomFactor
        cameraManager.setZoomFactor(newZoomFactor)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    @Binding var focusPoint: CGPoint
    @Binding var showFocusIndicator: Bool
    let onTap: (CGPoint) -> Void
    let onPinch: (CGFloat) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        // Add pinch gesture
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: CameraPreview
        
        init(_ parent: CameraPreview) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            parent.onTap(point)
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .changed {
                parent.onPinch(gesture.scale)
                gesture.scale = 1.0
            }
        }
    }
}

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?
    @Published var galleryThumbnail: UIImage?
    @Published var isFlashOn = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var completionHandler: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
        loadGalleryThumbnail()
    }
    
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            completion(granted)
        }
    }
    
    func setupCamera() {
        session.beginConfiguration()
        
        // Configure session
        session.sessionPreset = .photo
        
        // Add video input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            session.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
                currentDevice = camera
            }
        } catch {
            print("Error setting up camera input: \(error)")
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        session.stopRunning()
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        completionHandler = completion
        
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        
        if let device = currentDevice {
            if device.isFlashAvailable {
                settings.flashMode = device.flashMode
            }
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func switchCamera() {
        session.beginConfiguration()
        
        // Remove current input
        if let input = currentInput {
            session.removeInput(input)
        }
        
        // Switch camera position
        cameraPosition = cameraPosition == .back ? .front : .back
        
        // Add new input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            session.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
                currentDevice = camera
            }
        } catch {
            print("Error switching camera: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        guard let device = currentDevice, device.hasFlash else { return }
        
        do {
            try device.lockForConfiguration()
            device.flashMode = mode
            device.unlockForConfiguration()
        } catch {
            print("Error setting flash mode: \(error)")
        }
    }
    
    func focusAt(_ point: CGPoint) {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error focusing: \(error)")
        }
    }
    
    func setZoomFactor(_ factor: CGFloat) {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = factor
            device.unlockForConfiguration()
        } catch {
            print("Error setting zoom: \(error)")
        }
    }
    
    private func loadGalleryThumbnail() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                fetchOptions.fetchLimit = 1
                
                let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                
                if let asset = fetchResult.firstObject {
                    let imageManager = PHImageManager.default()
                    let options = PHImageRequestOptions()
                    options.isSynchronous = false
                    options.deliveryMode = .highQualityFormat
                    
                    imageManager.requestImage(for: asset, targetSize: CGSize(width: 50, height: 50), contentMode: .aspectFill, options: options) { image, _ in
                        DispatchQueue.main.async {
                            self.galleryThumbnail = image
                        }
                    }
                }
            }
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            completionHandler?(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completionHandler?(nil)
            return
        }
        
        saveImageToPhotoLibrary(image)
        completionHandler?(image)
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            if success {
                DispatchQueue.main.async {
                    self.loadGalleryThumbnail()
                }
            } else if let error = error {
                print("Error saving image: \(error)")
            }
        }
    }
}

struct PhotoLibraryView: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Photo Library")
                .navigationTitle("Gallery")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct ImagePreviewView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        // Share functionality
                    }
                }
            }
        }
    }
}