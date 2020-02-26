//
//  ViewController.swift
//  LowDataMode
//
//  Created by Derek Carter on 1/24/20.
//  Copyright © 2020 Derek Carter. All rights reserved.
//

import CoreLocation
import Foundation
import Network
import SystemConfiguration.CaptiveNetwork
import UIKit

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var connectionLabel: UILabel!
    @IBOutlet weak var networkLabel: UILabel!
    @IBOutlet weak var isConstrainedLabel: UILabel!
    @IBOutlet weak var isExpensiveLabel: UILabel!
    
    var locationManager: CLLocationManager!
    
    var reachability: Reachability!
    var lastKnownNetwork: String?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Request location services to get the SSID.  This is a requirement in iOS 13+.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        // Setup reachability
        reachability = Reachability()
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(notification:)), name: .reachabilityChanged, object: reachability)
        startReachability()
        
        // Setup notifications
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        startNWPathMonitor()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop reachability
        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
    }
    
    
    // MARK: - CLLocationManagerDelegate Methods
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .notDetermined {
            self.locationManager.requestWhenInUseAuthorization()
        }
        
        if status == .denied {
            let alertController = UIAlertController (title: "Location Services", message: "In order to use this app, please go to Settings and enable Location Services.", preferredStyle: .alert)
            let settingsAction = UIAlertAction(title: "Settings", style: .default) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        alertController.dismiss(animated: false, completion: nil)
                    })
                }
            }
            alertController.addAction(settingsAction)
            
            let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
            keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
        }
    }
    
    
    // MARK: - Reachability Methods
    
    func startReachability() {
        do {
            try reachability.startNotifier()
        }
        catch{
            print("Could not start Reachability")
        }
    }
    
    @objc func reachabilityChanged(notification: Notification) {
        var network: String?
        let reachability = notification.object as! Reachability
        switch reachability.connection {
        case .wifi:
            network = getSSIDName(nil)
            print("Reachability | Current Network: \(network ?? "unknown")   Last Known Network \(String(describing: lastKnownNetwork))")
        case .cellular:
            print("Reachability | Current Network: Cellular Network   Last Known Network \(String(describing: lastKnownNetwork))")
            network = getSSIDName("You are connected via cellular and using your data plan")
        case .none:
            print("Reachability | Current Network: Network not reachable   Last Known Network \(String(describing: lastKnownNetwork))")
            network = getSSIDName(nil)
        }
        
        lastKnownNetwork = network
    }
    
    func getSSID() -> String? {
        var ssid: String?
        if let interfaces = CNCopySupportedInterfaces() as NSArray? {
            for interface in interfaces {
                if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                    ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
                    break
                }
            }
        }
        return ssid
    }
    
    func getSSIDName(_ stringOverride: String?) -> String? {
        if let network = getSSID() {
            DispatchQueue.main.async {
                self.connectionLabel.text = "Wi-Fi"
                self.networkLabel.text = network
            }
            return network
        }
        else {
            DispatchQueue.main.async {
                if self.reachability.connection == .none {
                    self.connectionLabel.text = "No Connection"
                    self.networkLabel.text = "No Connection"
                }
                else if self.reachability.connection == .cellular {
                    self.connectionLabel.text = "Data"
                    self.networkLabel.text = "n/a"
                }
                else {
                    self.connectionLabel.text = "Wi-Fi"
                    if let stringOverride = stringOverride {
                        self.networkLabel.text = stringOverride
                    }
                    else {
                        self.networkLabel.text = "Unknown Network"
                    }
                }
            }
        }
        return nil
    }
    
    @objc func appDidBecomeActive() {
        // Detect ssid
        let network = getSSIDName(nil)
        if network != lastKnownNetwork {
            lastKnownNetwork = network
        }
    }
    
    
    // MARK: - NWPath Methods

    var queue: DispatchQueue!
    var monitor: NWPathMonitor!
    
    func startNWPathMonitor() {
        queue = DispatchQueue(label: "NWPathMonitorQueue")
        
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isExpensive = path.isExpensive
            if isExpensive {
                DispatchQueue.main.async {
                    self?.isExpensiveLabel.text = "True"
                }
            }
            else {
                DispatchQueue.main.async {
                    self?.isExpensiveLabel.text = "False"
                }
            }
            let isConstrained = path.isConstrained
            if isConstrained {
                DispatchQueue.main.async {
                    self?.isConstrainedLabel.text = "True"
                }
            }
            else {
                DispatchQueue.main.async {
                    self?.isConstrainedLabel.text = "False"
                }
            }
        }
        monitor.start(queue: queue)
        
        let isExpensive = monitor.currentPath.isExpensive
        if isExpensive {
            self.isExpensiveLabel.text = "True"
        }
        else {
            self.isExpensiveLabel.text = "False"
        }
        let isConstrained = monitor.currentPath.isConstrained
        if isConstrained {
            self.isConstrainedLabel.text = "True"
        }
        else {
            self.isConstrainedLabel.text = "False"
        }
    }
    
}
