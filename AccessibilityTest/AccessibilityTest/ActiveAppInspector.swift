import Cocoa
import ApplicationServices

class ActiveApplicationInspector {
    enum InspectorError: Error {
        case noActiveApp
        case permissionDenied(String)
        case accessibilityError(String)
    }
    
    /// Get the currently active application
    public func getActiveApplication() throws -> (NSRunningApplication, AXUIElement) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw InspectorError.noActiveApp
        }
        
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)
        
        // Verify we can access the application
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXRoleAttribute as CFString, &value)
        
        if result != .success {
            throw InspectorError.accessibilityError("""
                Cannot access application '\(app.localizedName ?? "Unknown")'.
                Error code: \(result.rawValue)
                """)
        }
        
        return (app, appRef)
    }
    
    /// Get focused window of the application
    private func getFocusedWindow(appRef: AXUIElement) throws -> AXUIElement {
        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowRef)
        
        guard result == .success else {
            throw InspectorError.accessibilityError("Could not get focused window")
        }
        
        // Direct force cast is safe here since we checked result == .success
        return windowRef as! AXUIElement
    }
    /// Get focused element in the window
    private func getFocusedElement(appRef: AXUIElement) throws -> AXUIElement {
        var focusedRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        
        guard result == .success else {
            throw InspectorError.accessibilityError("Could not get focused element")
        }
        
        // Direct force cast is safe here since we checked result == .success
        return focusedRef as! AXUIElement
        
    }
    
    public func getAllProperties(for element: AXUIElement) -> [String: Any] {
        var properties: [String: Any] = [:]
        var arrayRef: CFArray?
        
        // Get list of supported attributes
        guard AXUIElementCopyAttributeNames(element, &arrayRef) == .success,
              let attributeNames = arrayRef as? [String] else {
            return properties
        }
        
        // Get value for each attribute
        for attrName in attributeNames {
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attrName as CFString, &valueRef) == .success,
               let value = valueRef {
                properties[attrName] = value
            }
        }
        
        return properties
    }
}
