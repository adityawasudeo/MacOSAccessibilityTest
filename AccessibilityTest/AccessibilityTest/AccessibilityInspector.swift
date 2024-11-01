
import Cocoa
import ApplicationServices

class AccessibilityInspector {
    var activeAppInspector: ActiveApplicationInspector
    init() {
        activeAppInspector = ActiveApplicationInspector()
    }
    
    enum AccessibilityError: Error {
        case applicationNotFound
        case attributeError
        case permissionDenied(details: String)
        case trustedCheckFailed
    }
    
    // Common accessibility attributes to check
    static let commonAttributes: [String] = [
        kAXRoleAttribute as String,
        kAXRoleDescriptionAttribute as String,
        kAXChildrenAttribute as String,
        kAXTitleAttribute as String,
        kAXDescriptionAttribute as String,
        kAXValueAttribute as String,
        kAXEnabledAttribute as String,
        kAXFocusedAttribute as String,
        kAXPositionAttribute as String,
        kAXSizeAttribute as String
    ]
    
    private func checkAccessibilityPermissions() throws {
           // Check basic process trust
           
           let trusted = AXIsProcessTrustedWithOptions(nil)
           
            if !trusted {
               throw AccessibilityError.permissionDenied(details: """
                   Basic trust check failed.
                   AXIsProcessTrustedWithOptions returned: \(trusted)
                   Trust value: \(trusted)
                   Please ensure accessibility permissions are enabled.
                   """)
           }
       }
    
    /// Get the accessibility properties for an element
    private func getProperties(for element: AXUIElement) -> [String: Any] {
        var properties: [String: Any] = [:]
        
        for attribute in AccessibilityInspector.commonAttributes {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
            
            if result == .success, let value = value {
                if let stringValue = value as? String {
                    properties[attribute] = stringValue
                } else if let numberValue = value as? NSNumber {
                    properties[attribute] = numberValue
                } else if let pointValue = value as? NSPoint {
                    properties[attribute] = NSStringFromPoint(pointValue)
                } else if let sizeValue = value as? NSSize {
                    properties[attribute] = NSStringFromSize(sizeValue)
                } else {
                    properties[attribute] = "\(value)"
                }
            }
        }
        
        return properties
    }
    
    /// Recursively traverse the accessibility tree
    private func traverseAccessibilityTree(element: AXUIElement, depth: Int = 0) {
        let properties = getProperties(for: element)
        let indent = String(repeating: "  ", count: depth)
        print("\(indent)Element Properties:", properties)
        
        // Get children
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        
        if result == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                traverseAccessibilityTree(element: child, depth: depth + 1)
            }
        }
    }
    
    /// Inspect an application's accessibility tree
    func inspectApplication(named appName: String) throws {
        
        try checkAccessibilityPermissions()
        
        // Find the running application
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.localizedName == appName }) else {
            throw AccessibilityError.applicationNotFound
        }
        
        
        // Get the application's accessibility element
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)
        
        print("\nInspecting accessibility tree for \(appName) (PID: \(pid))")
        traverseAccessibilityTree(element: appRef)
    }
    
    /// Set up an observer for accessibility changes
    /*
     func watchElementChanges(for element: AXUIElement, callback: @escaping (String) -> Void) throws {
     var observer: AXObserver?
     let pid = ProcessInfo.processInfo.processIdentifier
     
     // Create observer
     guard AXObserverCreate(pid, { (observer, element, notification, userData) in
     let notificationString = notification as String
     callback(notificationString)
     }, &observer) == .success else {
     throw AccessibilityError.attributeError
     }
     
     guard let axObserver = observer else {
     throw AccessibilityError.attributeError
     }
     
     // Watch for common notifications
     let notifications = [
     kAXFocusedUIElementChangedNotification,
     kAXValueChangedNotification,
     kAXTitleChangedNotification,
     kAXWindowCreatedNotification,
     kAXWindowMovedNotification,
     kAXWindowResizedNotification
     ]
     
     for notification in notifications {
     AXObserverAddNotification(axObserver, element, notification as CFString, nil)
     }
     
     // Start the observer
     CFRunLoopAddSource(
     CFRunLoopGetCurrent(),
     AXObserverGetRunLoopSource(axObserver),
     .defaultMode
     )
     }
     } */
    
    
    // Error handling wrapper
    func inspectApp(named appName: String) {
        do {
            try inspector.inspectApplication(named: appName)
        } catch AccessibilityInspector.AccessibilityError.permissionDenied(let details) {
            print(details)
        } catch AccessibilityInspector.AccessibilityError.applicationNotFound {
            print("Error: Application '\(appName)' not found")
        } catch {
            print("Error: \(error)")
        }
    }
    
    func inspectActiveApp() throws {
        
        try checkAccessibilityPermissions()
        let seconds = 5
        for i in (1...seconds).reversed() {
            print("\(i)...")
            fflush(stdout)  // Ensure output is displayed immediately
            Thread.sleep(forTimeInterval: 1)
        }
        let (app, appRef) = try activeAppInspector.getActiveApplication()
        print("\nInspecting active application: \(app.localizedName ?? "Unknown")")
        
        traverseElement(appRef)
    }
    
    private func traverseElement(_ element: AXUIElement, depth: Int = 0, maxDepth: Int = 10) {
        if depth >= maxDepth { return }
        
        let properties = activeAppInspector.getAllProperties(for: element)
        printElementInfo(properties, depth: depth)
        
        // Get and traverse children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                traverseElement(child, depth: depth + 1, maxDepth: maxDepth)
            }
        }
    }
        
    private func printElementInfo(_ properties: [String: Any], depth: Int = 0) {
            let indent = String(repeating: "  ", count: depth)
            let role = properties[kAXRoleAttribute as String] as? String ?? "unknown"
            let roleDesc = properties[kAXRoleDescriptionAttribute as String] as? String ?? ""
            let title = properties[kAXTitleAttribute as String] as? String ?? ""
            let value = properties[kAXValueAttribute as String] as? String ?? ""
            
            var output = "\(indent)[\(role)] \(roleDesc)"
            if !title.isEmpty { output += "\n\(indent)  Title: \"\(title)\"" }
            if !value.isEmpty { output += "\n\(indent)  Value: \"\(value)\"" }
            
            print(output)
        }
    
    // Watch for changes
    /*
     func watchApp(named appName: String) {
     do {
     guard let app = NSWorkspace.shared.runningApplications
     .first(where: {
     $0.localizedName == appName
     }) else {
     print("Application not found")
     return
     }
     
     let appRef = AXUIElementCreateApplication(app.processIdentifier)
     
     try inspector.watchElementChanges(for: appRef) { notification in
     print("Change detected: \(notification)")
     }
     
     // Start the run loop
     RunLoop.current.run()
     } catch {
     print("Error setting up observer: \(error)")
     }
     } */
    
    // Example calls:
    //inspectApp(named: "Google Chrome")
    // watchApp(named: "Google Chrome")  // Uncomment to watch for changes
}

