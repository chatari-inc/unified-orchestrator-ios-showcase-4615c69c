// filepath: CameraView.swift

import SwiftUI
import AVFoundation
import Photos

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingGallery = false
    @State private var showingSettings = false
    @State private var capturedImage: UIImage?
    @State private var flashMode: AVCaptureDevice.FlashMode = .auto
    @State private var showGrid = false
    @State private var timerDuration = 0
    @State private var zoomFactor: CGFloat = 1.0
    @State private var lastZoomFactor: CGFloat = 1.0
    @State private var showingImagePreview = false
    @State private var isCapturing = false
    @State private var focusPoint: CGPoint?
    @State private var showFocusIndicator = false
    @State private var galleryThumbnail: UIImage?
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(
                session: cameraManager.session,
                onTap: { point in
                    focusCamera(at: point)
                }
            )
            .ignoresSafeArea()
            .scaleEffect(zoomFactor)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastZoomFactor
                        lastZoomFactor = value
                        let newZoom = min(max(zoomFactor * delta, 1.0), 5.0)
                        zoomFactor = newZoom
                        cameraManager.setZoomFactor(newZoom)
                    }
                    .onEnded { _ in
                        lastZoomFactor = 1.0
                    }
            )
            
            // Grid overlay
            if showGrid {
                gridOverlay
            }
            
            // Focus indicator
            if showFocusIndicator, let focusPoint = focusPoint {
                focusIndicator
                    .position(focusPoint)
            }
            
            // Top controls
            topControls
            
            // Bottom controls
            bottomControls
            
            // Settings panel
            if showingSettings {
                settingsPanel
            }
        }
        .onAppear {
            setupCamera()
            loadGalleryThumbnail()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showingGallery) {
            PhotoLibraryView(selectedImage: $capturedImage)
        }
        .sheet(isPresented: $showingImagePreview) {
            if let image = capturedImage {
                ImagePreviewView(image: image, onSave: saveToGallery, onDiscard: discardImage)
            }
        }
        .alert("Camera Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
        .onChange(of: cameraManager.error) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
        .onChange(of: cameraManager.capturedImage) { image in
            if let image = image {
                capturedImage = image
                showingImagePreview = true
                isCapturing = false
            }
        }
    }
    
    private var topControls: some View {
        VStack {
            HStack {
                // Flash control
                Button(action: toggleFlash) {
                    Image(systemName: flashIconName)
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 40, height: 40))
                }
                .accessibilityLabel("Flash: \(flashMode.description)")
                
                Spacer()
                
                // Settings button
                Button(action: { showingSettings.toggle() }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 40, height: 40))
                }
                .accessibilityLabel("Camera Settings")
                
                // Close button
                Button(action: { }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 40, height: 40))
                }
                .accessibilityLabel("Close Camera")
            }
            .padding()
            
            Spacer()
        }
    }
    
    private var bottomControls: some View {
        VStack {
            Spacer()
            
            // Zoom indicator
            if zoomFactor > 1.0 {
                Text("\(zoomFactor, specifier: "%.1f")x")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    .padding(.bottom, 8)
            }
            
            HStack(spacing: 50) {
                // Gallery button
                Button(action: { showingGallery = true }) {
                    Group {
                        if let thumbnail = galleryThumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "photo.on.rectangle")
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
                .accessibilityLabel("Open Photo Gallery")
                
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
                }
                .disabled(isCapturing)
                .accessibilityLabel("Capture Photo")
                
                // Camera switch button
                Button(action: switchCamera) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .accessibilityLabel("Switch Camera")
            }
            .padding(.bottom, 50)
        }
    }
    
    private var gridOverlay: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Vertical lines
                Path { path in
                    path.move(to: CGPoint(x: width / 3, y: 0))
                    path.addLine(to: CGPoint(x: width / 3, y: height))
                    path.move(to: CGPoint(x: 2 * width / 3, y: 0))
                    path.addLine(to: CGPoint(x: 2 * width / 3, y: height))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                
                // Horizontal lines
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height / 3))
                    path.addLine(to: CGPoint(x: width, y: height / 3))
                    path.move(to: CGPoint(x: 0, y: 2 * height / 3))
                    path.addLine(to: CGPoint(x: width, y: 2 * height / 3))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
    
    private var focusIndicator: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .opacity(showFocusIndicator ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.3), value: showFocusIndicator)
    }
    
    private var settingsPanel: some View {
        VStack(spacing: 20) {
            Text("Camera Settings")
                .font(.headline)
                .foregroundColor(.white)
            
            // Flash mode picker
            VStack(alignment: .leading) {
                Text("Flash Mode")
                    .foregroundColor(.white)
                    .font(.subheadline)
                
                Picker("Flash Mode", selection: $flashMode) {
                    Text("Auto").tag(AVCaptureDevice.FlashMode.auto)
                    Text("On").tag(AVCaptureDevice.FlashMode.on)
                    Text("Off").tag(AVCaptureDevice.FlashMode.off)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: flashMode) { mode in
                    cameraManager.setFlashMode(mode)
                }
            }
            
            // Grid toggle
            Toggle("Show Grid", isOn: $showGrid)
                .foregroundColor(.white)
            
            // Timer picker
            VStack(alignment: .leading) {
                Text("Timer")
                    .foregroundColor(.white)
                    .font(.subheadline)
                
                Picker("Timer", selection: $timerDuration) {
                    Text("Off").tag(0)
                    Text("3s").tag(3)
                    Text("10s").tag(10)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Button("Close") {
                showingSettings = false
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .padding()
    }
    
    private var flashIconName: String {
        switch flashMode {
        case .auto:
            return "bolt.badge.a.fill"
        case .on:
            return "bolt.fill"
        case .off:
            return "bolt.slash.fill"
        @unknown default:
            return "bolt.badge.a.fill"
        }
    }
    
    private func setupCamera() {
        cameraManager.requestPermissions { granted in
            if granted {
                cameraManager.setupCamera()
            } else {
                errorMessage = "Camera permission is required"
                showingError = true
            }
        }
    }
    
    private func capturePhoto() {
        isCapturing = true
        
        if timerDuration > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(timerDuration)) {
                cameraManager.capturePhoto()
            }
        } else {
            cameraManager.capturePhoto()
        }
    }
    
    private func switchCamera() {
        cameraManager.switchCamera()
        zoomFactor = 1.0
    }
    
    private func toggleFlash() {
        switch flashMode {
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        case .off:
            flashMode = .auto
        @unknown default:
            flashMode = .auto
        }
        cameraManager.setFlashMode(flashMode)
    }
    
    private func focusCamera(at point: CGPoint) {
        focusPoint = point
        showFocusIndicator = true
        cameraManager.focus(at: point)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showFocusIndicator = false
        }
    }
    
    private func saveToGallery() {
        guard let image = capturedImage else { return }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    loadGalleryThumbnail()
                } else {
                    errorMessage = "Failed to save photo"
                    showingError = true
                }
                showingImagePreview = false
            }
        }
    }
    
    private func discardImage() {
        capturedImage = nil
        showingImagePreview = false
    }
    
    private func loadGalleryThumbnail() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        if let asset = fetchResult.firstObject {
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .fastFormat
            
            manager.requestImage(for: asset, targetSize: CGSize(width: 50, height: 50), contentMode: .aspectRatio, options: options) { image, _ in
                DispatchQueue.main.async {
                    galleryThumbnail = image
                }
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: (CGPoint) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
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
    }
}

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?
    @Published var error: Error?
    @Published var isFlashOn = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    override init() {
        super.init()
    }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
            PHPhotoLibrary.requestAuthorization { photoStatus in
                DispatchQueue.main.async {
                    completion(videoGranted && photoStatus == .authorized)
                }
            }
        }
    }
    
    func setupCamera() {
        sessionQueue.async {
            self.session.beginConfiguration()
            
            // Remove existing inputs
            self.session.inputs.forEach { input in
                self.session.removeInput(input)
            }
            
            // Remove existing outputs
            self.session.outputs.forEach { output in
                self.session.removeOutput(output)
            }
            
            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.cameraPosition) else {
                DispatchQueue.main.async {
                    self.error = CameraError.deviceNotAvailable
                }
                return
            }
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                    self.currentInput = videoInput
                    self.currentDevice = videoDevice
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                }
                return
            }
            
            // Add photo output
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.isHighResolutionCaptureEnabled = true
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
    
    func capturePhoto() {
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            settings.flashMode = self.isFlashOn ? .on : .off
            settings.isHighResolutionPhotoEnabled = true
            
            if let photoPreviewType = settings.availablePreviewPhotoPixelFormatTypes.first {
                settings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
            }
            
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func switchCamera() {
        sessionQueue.async {
            self.cameraPosition = self.cameraPosition == .back ? .front : .back
            self.setupCamera()
        }
    }
    
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        sessionQueue.async {
            guard let device = self.currentDevice, device.hasFlash else { return }
            
            do {
                try device.lockForConfiguration()
                device.flashMode = mode
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.isFlashOn = mode == .on
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        }
    }
    
    func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async {
            guard let device = self.currentDevice else { return }
            
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = min(max(factor, 1.0), device.activeFormat.videoMaxZoomFactor)
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        }
    }
    
    func focus(at point: CGPoint) {
        sessionQueue.async {
            guard let device = self.currentDevice, device.isFocusPointOfInterestSupported else { return }
            
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            self.session.stopRunning()
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.error = CameraError.imageProcessingFailed
            }
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}

enum CameraError: Error, LocalizedError {
    case deviceNotAvailable
    case imageProcessingFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Camera device not available"
        case .imageProcessingFailed:
            return "Failed to process captured image"
        case .permissionDenied:
            return "Camera permission denied"
        }
    }
}

extension AVCaptureDevice.FlashMode {
    var description: String {
        switch self {
        case .auto:
            return "Auto"
        case .on:
            return "On"
        case .off:
            return "Off"
        @unknown default:
            return "Auto"
        }
    }
}

struct PhotoLibraryView: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    @State private var images: [UIImage] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 2) {
                    ForEach(images.indices, id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipped()
                            .onTapGesture {
                                selectedImage = images[index]
                                presentationMode.wrappedValue.dismiss()
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            loadPhotos()
        }
    }
    
    private func loadPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 50
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        fetchResult.enumerateObjects { asset, _, _ in
            manager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectRatio, options: options) { image, _ in
                if let image = image {
                    DispatchQueue.main.async {
                        self.images.append(image)
                    }
                }
            }
        }
    }
}

struct ImagePreviewView: View {
    let image: UIImage
    let onSave: () -> Void
    let onDiscard: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                
                Spacer()
                
                HStack(spacing: 50) {
                    Button("Discard") {
                        onDiscard()
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    
                    Button("Save") {
                        onSave()
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding(.bottom, 50)
            }
        }
    }
}