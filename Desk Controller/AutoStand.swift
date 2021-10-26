//
//  AutoStand.swift
//  Desk Controller
//
//  Created by Johan Eklund on 2021-03-05.
//

import Foundation

class AutoStand: NSObject {
    
    private var upTimer: Timer?
    private var downTimer: Timer?
    
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
                let oneHour:TimeInterval = 3600
                let nextDown = now.nextHour
                var nextUp = Date.init(timeInterval: -Preferences.shared.automaticStandPerHour, since: nextDown)
                
                // Dont schedule in the past
                if nextUp < now {
                    nextUp = now + oneHour
                }
                
                upTimer = Timer.init(fire: nextUp, interval: oneHour, repeats: true, block: {_ in
                    
                    let lastEvent = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: CGEventType(rawValue: ~0)!)

                    if  lastEvent < Preferences.shared.automaticStandInactivity {
                        DeskController.shared?.moveToPosition(.stand)
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
