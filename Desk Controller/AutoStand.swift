//
//  AutoStand.swift
//  Desk Controller
//
//  Created by Johan Eklund on 2021-03-05.
//

import Foundation
import LogWatcher

class AutoStand: NSObject {
    private var upTimer: Timer?
    private var downTimer: Timer?

    private var camTracker: SysLogWatcher?
    public var lastKnownCameraState: CameraState = .unknown
    
    public var cameraStateChanged: ((CameraState) -> Void)?

    override init() {
        super.init()
        let eventProducer = CameraEventProducer()
        camTracker = SysLogWatcher(predicates: eventProducer.predicates, eventProducer: eventProducer) { [weak self] result in
            guard let self = self else { return }

            switch(result) {
                    case .success(let event):
                        switch(event) {
                        case .Start:
                            DispatchQueue.main.async {
                                self.lastKnownCameraState = .on
                                self.cameraStateChanged?(self.lastKnownCameraState)
                            }
                        case .Stop:
                            DispatchQueue.main.async {
                                self.lastKnownCameraState = .off
                                self.cameraStateChanged?(self.lastKnownCameraState)
                            }
                        }
                    case .failure(let data):
                        NSLog("Error decoding data \(data)")
            }
        }
    }
    
    func onCameraStateChange(_ callback: @escaping (CameraState) -> Void) {
        self.cameraStateChanged = callback
    }
    
    // update() can get called in overlapping ways between combo of resume from sleep and reconnecting to a device. Alt fix, make sure it is only called once..?
    let queue = DispatchQueue(label: "autostandupdate", qos: .userInteractive)
    
    func update() {
        queue.async { [self] in
            upTimer?.invalidate()
            downTimer?.invalidate()
            //NSLog("Invalidated auto timers.")
            
            if Preferences.shared.automaticStandEnabled {
                // Stand session always end at top of hour
                let now = Date()
                let oneMinute:TimeInterval = 60
                let oneHour:TimeInterval = 3600
                let nextDown = Date.init(timeInterval: -oneMinute, since: now.nextHour) // tune stand to go back to sit 1 minute before the end of the hour, instead of on the hour change.
                var nextUp = Date.init(timeInterval: -Preferences.shared.automaticStandPerHour, since: nextDown)
                
                // Dont schedule in the past
                if nextUp < now {
                    nextUp = now + oneHour
                }
                
                upTimer = Timer.init(fire: nextUp, interval: oneHour, repeats: true, block: {_ in
                    
                    let lastEvent = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: CGEventType(rawValue: ~0)!)

                    if  lastEvent < Preferences.shared.automaticStandInactivity {
                        if self.lastKnownCameraState != .on {
                            DeskController.shared?.moveToPosition(.stand)
                        } else {
                            NSLog("cam: Not auto standing because camera last known state active")
                        }
                    }
                    NSLog("Fired up timer: \(Date().description(with: .current))")
                })
                
                downTimer = Timer.init(fire: nextDown, interval: oneHour, repeats: true, block: {_ in
                    // Always return to sitting, even if inactive
                    DeskController.shared?.moveToPosition(.sit)
                    NSLog("Fired down timer: \(Date().description(with: .current))")
                })
                
                RunLoop.main.add(upTimer!, forMode: .common)
                RunLoop.main.add(downTimer!, forMode: .common)
                
                NSLog("Scheduled timers:\n\tUp: \(nextUp.description(with: .current))\n\tDown: \(nextDown.description(with: .current))")
            }
        }
    }
}

enum CameraState: String {
    case on
    case off
    case unknown
}

enum CameraEvent {
    case Start
    case Stop
}
