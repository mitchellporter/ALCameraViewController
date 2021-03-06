//
//  ALCameraViewController.swift
//  ALCameraViewController
//
//  Created by Alex Littlejohn on 2015/06/17.
//  Copyright (c) 2015 zero. All rights reserved.
//

import UIKit
import AVFoundation

public typealias ALCameraViewCompletion = (UIImage?) -> Void

public extension ALCameraViewController {
    public class func imagePickerViewController(croppingEnabled: Bool, completion: ALCameraViewCompletion) -> UINavigationController {
        let imagePicker = ALImagePickerViewController()
        let navigationController = UINavigationController(rootViewController: imagePicker)
        
        navigationController.navigationBar.barTintColor = UIColor.blackColor()
        navigationController.navigationBar.barStyle = UIBarStyle.Black
        
        imagePicker.onSelectionComplete = { image in
            if image != nil {
                let confirmController = ALConfirmViewController(image: image!, allowsCropping: croppingEnabled)
                confirmController.onComplete = { image in
                    if let i = image {
                        completion(i)
                    } else {
                        imagePicker.dismissViewControllerAnimated(true, completion: nil)
                    }
                }
                confirmController.modalTransitionStyle = UIModalTransitionStyle.CrossDissolve
                imagePicker.presentViewController(confirmController, animated: true, completion: nil)
            } else {
                completion(nil)
            }
        }
        
        imagePicker.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "libraryCancel", inBundle: NSBundle(forClass: ALCameraViewController.self), compatibleWithTraitCollection: nil)?.imageWithRenderingMode(UIImageRenderingMode.AlwaysOriginal), style: UIBarButtonItemStyle.Plain, target: imagePicker, action: "dismiss")
        
        return navigationController
    }
    
    public class func croppingViewController(image: UIImage, croppingEnabled: Bool, completion: ALCameraViewCompletion) -> UIViewController {
        let cropper = ALConfirmViewController(image: image, allowsCropping: croppingEnabled)
        cropper.onComplete = completion
        return cropper
    }
}

public class ALCameraViewController: UIViewController {
    
    let cameraView = ALCameraView()
    let cameraOverlay = ALCropOverlay()
    let cameraButton = UIButton()
    
    let closeButton = UIButton()
    
    var onCompletion: ALCameraViewCompletion?
    var allowCropping = false
    
    var verticalPadding: CGFloat = 30
    var horizontalPadding: CGFloat = 30
    
    public init(croppingEnabled: Bool, completion: ALCameraViewCompletion) {
        super.init(nibName: nil, bundle: nil)
        onCompletion = completion
        allowCropping = croppingEnabled
        commonInit()
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    public override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    public override func preferredStatusBarUpdateAnimation() -> UIStatusBarAnimation {
        return UIStatusBarAnimation.Slide
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.blackColor()
        view.addSubview(cameraView)
        
        
        if allowCropping {
            layoutCropView()
        }
        
        cameraView.frame = view.bounds
        
        rotate()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "rotate", name: UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    public override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .Portrait
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        checkPermissions()
    }
    
    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        cameraView.frame = view.bounds
        cameraEndState()
    }
    
    internal func rotate() {
        let rotation = currentRotation()
        let rads = CGFloat(radians(rotation))
        
        UIView.animateWithDuration(0.3) {
            self.cameraButton.transform = CGAffineTransformMakeRotation(rads)
            self.closeButton.transform = CGAffineTransformMakeRotation(rads)
        }
    }
    
    private func commonInit() {
        if UIScreen.mainScreen().bounds.size.width <= 320 {
            verticalPadding = 15
            horizontalPadding = 15
        }
    }

    private func checkPermissions() {
        if AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) == AVAuthorizationStatus.Authorized {
            startCamera()
        } else {
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo) { granted in
                dispatch_async(dispatch_get_main_queue()) {
                    if granted == true {
                        self.startCamera()
                    } else {
                        self.showNoPermissionsView()
                    }
                }
            }
        }
    }
    
    private func showNoPermissionsView() {
        let permissionsView = ALPermissionsView(frame: view.bounds)
        view.addSubview(permissionsView)
        view.addSubview(closeButton)
        
        closeButton.addTarget(self, action: "close", forControlEvents: UIControlEvents.TouchUpInside)
        closeButton.setImage(UIImage(named: "retakeButton", inBundle: NSBundle(forClass: ALCameraViewController.self), compatibleWithTraitCollection: nil), forState: UIControlState.Normal)
        closeButton.sizeToFit()
        
        let size = view.frame.size
        let closeSize = closeButton.frame.size
        let closeX = horizontalPadding
        let closeY = size.height - (closeSize.height + verticalPadding)
        
        closeButton.frame.origin = CGPointMake(closeX, closeY)
    }
    
    private func startCamera() {
        cameraView.startSession()
        cameraButton.addTarget(self, action: "capturePhoto", forControlEvents: .TouchUpInside)
        closeButton.addTarget(self, action: "close", forControlEvents: .TouchUpInside)
        layoutCamera()
    }
    
    private func layoutCropView() {
        
        let size = view.frame.size
        let minDimension = size.width < size.height ? size.width : size.height
        let maxDimension = size.width > size.height ? size.width : size.height
        let width = minDimension - horizontalPadding
        let height = width
        let x = horizontalPadding/2
        
        let cameraButtonY = maxDimension - (verticalPadding + 80)
        let y = cameraButtonY/2 - height/2
        let frame = CGRectMake(x, y, width, height)
        
        view.addSubview(cameraOverlay)
        cameraOverlay.frame = frame
    }
    
    private func layoutCamera() {
        
        cameraButton.setImage(UIImage(named: "cameraButton", inBundle: NSBundle(forClass: ALCameraViewController.self), compatibleWithTraitCollection: nil), forState: .Normal)
        cameraButton.setImage(UIImage(named: "cameraButtonHighlighted", inBundle: NSBundle(forClass: ALCameraViewController.self), compatibleWithTraitCollection: nil), forState: .Highlighted)

        closeButton.setImage(UIImage(named: "closeButton", inBundle: NSBundle(forClass: ALCameraViewController.self), compatibleWithTraitCollection: nil), forState: .Normal)
        
        cameraButton.sizeToFit()
        closeButton.sizeToFit()
        
        view.addSubview(cameraButton)
        view.addSubview(closeButton)
        
        cameraButton.enabled = true
        cameraEndState()
    }
    
    private func cameraEndState() {
        let size = view.frame.size
        
        let cameraSize = cameraButton.frame.size
        let cameraX = size.width/2 - cameraSize.width/2
        let cameraY = size.height - (cameraSize.height + verticalPadding)
        
        cameraButton.frame.origin = CGPointMake(cameraX, cameraY)
        cameraButton.alpha = 1
        
        let closeSize = closeButton.frame.size
        let closeX = horizontalPadding
        let closeY = cameraY + (cameraSize.height - closeSize.height)/2
        
        closeButton.frame.origin = CGPointMake(closeX, closeY)
        closeButton.alpha = 1
        
    }
    
    internal func capturePhoto() {
        cameraButton.enabled = false
        cameraView.capturePhoto { image in
            self.layoutCameraResult(image)
        }
    }
    
    internal func close() {
        onCompletion?(nil)
    }
    
    internal func onConfirmComplete(image: UIImage?) {
        dismissViewControllerAnimated(true, completion: nil)
        onCompletion?(image)
    }
    
    internal func toggleFlash() {
        let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        if (device.hasTorch) {
            do {
                try device.lockForConfiguration()
                if (device.torchMode == AVCaptureTorchMode.On) {
                    device.torchMode = AVCaptureTorchMode.Off
                } else {
                    try device.setTorchModeOnWithLevel(AVCaptureMaxAvailableTorchLevel)
                }
                device.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }
    
    internal func swapCamera() {
        cameraView.swapCameraInput()
    }
    
    internal func layoutCameraResult(image: UIImage) {
        cameraView.stopSession()
        
        let confirmViewController = ALConfirmViewController(image: image, allowsCropping: allowCropping)
        
        confirmViewController.onComplete = { image in
            if image == nil {
                self.dismissViewControllerAnimated(true, completion: nil)
            } else {
                self.onCompletion?(image)
            }
        }
        confirmViewController.modalTransitionStyle = UIModalTransitionStyle.CrossDissolve
        
        presentViewController(confirmViewController, animated: true, completion: nil)
    }
}
