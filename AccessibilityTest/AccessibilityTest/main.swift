
import Foundation


let inspector = AccessibilityInspector()
//inspector.inspectApp(named: "Google Chrome")
try inspector.inspectActiveApp()
