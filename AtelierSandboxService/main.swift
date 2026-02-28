import Foundation
import AtelierSandbox

let delegate = SandboxServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()

RunLoop.main.run()
