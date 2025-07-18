// filepath: CameraView.swift

import SwiftUI
import AVFoundation
import Photos

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?
    @Published var isFlashOn = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var zoomLevel: CGFloat = 1.0
    @Published var focusPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @Published var exposureLevel: Float = 0.0
    @Published var isSessionRunning = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    override init() {
        super.init()
        checkCameraPermission()
        checkPhotoLibraryPermission()
    }
    
    func checkCameraPermission() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authorizationStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self.setupCamera()
                    }
                }
            }
        } else if authorizationStatus == .authorized {
            setupCamera()
        }
    }
    
    func checkPhotoLibraryPermission() {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus()
        if photoLibraryStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.photoLibraryStatus = status
                }
            }
        }
    }
    
    func setupCamera() {
        session.beginConfiguration()
        
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            session.commitConfiguration()
            return
        }
        
        currentDevice = camera
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if let currentInput = videoDeviceInput {
                session.removeInput(currentInput)
            }
            
            if session.canAddInput(input) {
                session.addInput(input)
                videoDeviceInput = input
            }
            
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
                photoOutput.isLivePhotoCaptureEnabled = false
            }
            
            session.commitConfiguration()
            
        } catch {
            print("Error setting up camera: \(error)")
            session.commitConfiguration()
        }
    }
    
    func startSession() {
        if !isSessionRunning {
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        if isSessionRunning {
            DispatchQueue.global(qos: .background).async {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        settings.isHighResolutionPhotoEnabled = true
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func switchCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        setupCamera()
    }
    
    func setZoom(_ zoom: CGFloat) {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            let maxZoom = min(zoom, device.activeFormat.videoMaxZoomFactor)
            device.videoZoomFactor = maxZoom
            zoomLevel = maxZoom
            device.unlockForConfiguration()
        } catch {
            print("Error setting zoom: \(error)")
        }
    }
    
    func setFocusAndExposure(at point: CGPoint) {
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
            
            focusPoint = point
            device.unlockForConfiguration()
        } catch {
            print("Error setting focus and exposure: \(error)")
        }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Error capturing photo: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = image
            self.savePhotoToLibrary(image)
        }
    }
    
    private func savePhotoToLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            if let error = error {
                print("Error saving photo: \(error)")
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    @Binding var focusPoint: CGPoint
    let onTapToFocus: (CGPoint) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
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
            let location = gesture.location(in: gesture.view)
            let view = gesture.view!
            let focusPoint = CGPoint(x: location.x / view.bounds.width, y: location.y / view.bounds.height)
            parent.onTapToFocus(focusPoint)
        }
    }
}

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingGallery = false
    @State private var showingSettings = false
    @State private var capturedImage: UIImage?
    @State private var flashMode: AVCaptureDevice.FlashMode = .auto
    @State private var showGrid = false
    @State private var timerDuration = 0
    @State private var isCapturing = false
    @State private var showingCapturedImage = false
    @State private var galleryImages: [UIImage] = []
    @State private var showingPermissionAlert = false
    @State private var pinchScale: CGFloat = 1.0
    @State private var lastPinchScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraManager.authorizationStatus == .authorized {
                cameraContent
            } else {
                permissionView
            }
        }
        .onAppear {
            cameraManager.startSession()
            loadGalleryImages()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: cameraManager.capturedImage) { image in
            if let image = image {
                capturedImage = image
                showingCapturedImage = true
            }
        }
        .sheet(isPresented: $showingCapturedImage) {
            if let image = capturedImage {
                ImagePreviewView(image: image, onDismiss: {
                    showingCapturedImage = false
                    capturedImage = nil
                })
            }
        }
        .sheet(isPresented: $showingGallery) {
            GalleryView(images: galleryImages, onDismiss: {
                showingGallery = false
            })
        }
        .sheet(isPresented: $showingSettings) {
            CameraSettingsView(
                flashMode: $flashMode,
                showGrid: $showGrid,
                timerDuration: $timerDuration,
                onDismiss: { showingSettings = false }
            )
        }
        .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable camera access in Settings to use this feature.")
        }
    }
    
    private var cameraContent: some View {
        ZStack {
            CameraPreview(
                session: cameraManager.session,
                focusPoint: $cameraManager.focusPoint
            ) { point in
                cameraManager.setFocusAndExposure(at: point)
            }
            .ignoresSafeArea()
            .scaleEffect(pinchScale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastPinchScale
                        lastPinchScale = value
                        let newScale = pinchScale * delta
                        pinchScale = max(1.0, min(newScale, 6.0))
                        cameraManager.setZoom(pinchScale)
                    }
                    .onEnded { value in
                        lastPinchScale = 1.0
                    }
            )
            
            if showGrid {
                gridOverlay
            }
            
            focusIndicator
            
            VStack {
                topControls
                Spacer()
                bottomControls
            }
        }
    }
    
    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please allow camera access to take photos")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Enable Camera") {
                if cameraManager.authorizationStatus == .denied {
                    showingPermissionAlert = true
                } else {
                    cameraManager.checkCameraPermission()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var topControls: some View {
        HStack {
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Button(action: cameraManager.toggleFlash) {
                Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title2)
                    .foregroundColor(cameraManager.isFlashOn ? .yellow : .white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            Button(action: { showGrid.toggle() }) {
                Image(systemName: "grid")
                    .font(.title2)
                    .foregroundColor(showGrid ? .yellow : .white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    
    private var bottomControls: some View {
        HStack {
            Button(action: { showingGallery = true }) {
                if let firstImage = galleryImages.first {
                    Image(uiImage: firstImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white)
                        )
                }
            }
            
            Spacer()
            
            Button(action: capturePhoto) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(Color.black, lineWidth: 3)
                        .frame(width: 70, height: 70)
                    
                    if isCapturing {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 60, height: 60)
                    }
                }
                .scaleEffect(isCapturing ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isCapturing)
            }
            .disabled(isCapturing)
            
            Spacer()
            
            Button(action: cameraManager.switchCamera) {
                Image(systemName: "camera.rotate.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    
    private var gridOverlay: some View {
        VStack {
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
            }
            .frame(height: 1)
            
            Spacer()
            
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
            }
            .frame(height: 1)
            
            Spacer()
            
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
            }
            .frame(height: 1)
        }
        .overlay(
            HStack {
                VStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1)
                }
                
                Spacer()
                
                VStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1)
                }
                
                Spacer()
                
                VStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1)
                }
            }
        )
        .ignoresSafeArea()
    }
    
    private var focusIndicator: some View {
        GeometryReader { geometry in
            Circle()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 60, height: 60)
                .position(
                    x: cameraManager.focusPoint.x * geometry.size.width,
                    y: cameraManager.focusPoint.y * geometry.size.height
                )
                .opacity(cameraManager.focusPoint.x == 0.5 && cameraManager.focusPoint.y == 0.5 ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: cameraManager.focusPoint)
        }
    }
    
    private func capturePhoto() {
        isCapturing = true
        
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        if timerDuration > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(timerDuration)) {
                cameraManager.capturePhoto()
                isCapturing = false
            }
        } else {
            cameraManager.capturePhoto()
            isCapturing = false
        }
    }
    
    private func loadGalleryImages() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 10
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .fastFormat
        
        var images: [UIImage] = []
        
        for i in 0..<fetchResult.count {
            let asset = fetchResult.object(at: i)
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFill, options: requestOptions) { image, _ in
                if let image = image {
                    images.append(image)
                    if images.count == fetchResult.count {
                        DispatchQueue.main.async {
                            self.galleryImages = images
                        }
                    }
                }
            }
        }
    }
}

struct ImagePreviewView: View {
    let image: UIImage
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Photo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

struct GalleryView: View {
    let images: [UIImage]
    let onDismiss: () -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(images.indices, id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Rectangle())
                    }
                }
                .padding()
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

struct CameraSettingsView: View {
    @Binding var flashMode: AVCaptureDevice.FlashMode
    @Binding var showGrid: Bool
    @Binding var timerDuration: Int
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Camera Settings") {
                    Toggle("Show Grid", isOn: $showGrid)
                    
                    Picker("Timer", selection: $timerDuration) {
                        Text("Off").tag(0)
                        Text("3 seconds").tag(3)
                        Text("10 seconds").tag(10)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Flash") {
                    Picker("Flash Mode", selection: $flashMode) {
                        Text("Auto").tag(AVCaptureDevice.FlashMode.auto)
                        Text("On").tag(AVCaptureDevice.FlashMode.on)
                        Text("Off").tag(AVCaptureDevice.FlashMode.off)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Camera Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CameraView()
}