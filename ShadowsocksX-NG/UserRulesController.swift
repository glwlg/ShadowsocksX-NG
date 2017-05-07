//
//  UserRulesController.swift
//  ShadowsocksX-NG
//
//

import Cocoa

class UserRulesController: NSWindowController {

    @IBOutlet var userRulesView: NSTextView!

    // 加载已有的用户规则
    override func windowDidLoad() {
        super.windowDidLoad()

        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: PACUserRuleFilePath) {
            let src = Bundle.main.path(forResource: "user-rule", ofType: "txt")
            try! fileMgr.copyItem(atPath: src!, toPath: PACUserRuleFilePath)
        }

        let str = try? String(contentsOfFile: PACUserRuleFilePath, encoding: String.Encoding.utf8)
        userRulesView.string = str
    }
    
    // 取消
    @IBAction func didCancel(_ sender: AnyObject) {
        window?.performClose(self)
    }

    // 保存并写入文件
    @IBAction func didOK(_ sender: AnyObject) {
        if let str = userRulesView.string {
            do {
                try str.data(using: String.Encoding.utf8)?.write(to: URL(fileURLWithPath: PACUserRuleFilePath), options: .atomic)

                if GeneratePACFile() {
                    // Popup a user notification
                    let notification = NSUserNotification()
                    notification.title = "PAC has been updated by User Rules.".localized
                    NSUserNotificationCenter.default
                        .deliver(notification)
                } else {
                    let notification = NSUserNotification()
                    notification.title = "It's failed to update PAC by User Rules.".localized
                    NSUserNotificationCenter.default
                        .deliver(notification)
                }
            } catch {}
        }
        window?.performClose(self)
    }
}
