//
//  BGUtils.swift
//  ShadowsocksX-NG
//
//

import Foundation

let SS_LOCAL_VERSION = "3.0.5"
let KCPTUN_CLIENT_VERSION = "20170322"
let PRIVOXY_VERSION = "3.0.26.static"
let APP_SUPPORT_DIR = "/Library/Application Support/ShadowsocksX-NG/"
let LAUNCH_AGENT_DIR = "/Library/LaunchAgents/"
let LAUNCH_AGENT_CONF_SSLOCAL_NAME = "com.qiuyuzhou.shadowsocksX-NG.local.plist"
let LAUNCH_AGENT_CONF_PRIVOXY_NAME = "com.qiuyuzhou.shadowsocksX-NG.http.plist"
let LAUNCH_AGENT_CONF_KCPTUN_NAME = "com.qiuyuzhou.shadowsocksX-NG.kcptun.plist"


func getFileSHA1Sum(_ filepath: String) -> String {
    if let data = try? Data(contentsOf: URL(fileURLWithPath: filepath)) {
        return data.sha1()
    }
    return ""
}

// Ref: https://developer.apple.com/library/mac/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html
// Genarate the mac launch agent service plist

//  MARK: sslocal
// 设置输出的log文件和对应的本地参数
func generateSSLocalLauchAgentPlist() -> Bool {
    let sslocalPath = NSHomeDirectory() + APP_SUPPORT_DIR + "ss-local-latest/ss-local"
    let logFilePath = NSHomeDirectory() + "/Library/Logs/ss-local.log"
    let launchAgentDirPath = NSHomeDirectory() + LAUNCH_AGENT_DIR
    let plistFilepath = launchAgentDirPath + LAUNCH_AGENT_CONF_SSLOCAL_NAME
    
    // Ensure launch agent directory is existed.
    let fileMgr = FileManager.default
    if !fileMgr.fileExists(atPath: launchAgentDirPath) {
        try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let oldSha1Sum = getFileSHA1Sum(plistFilepath)
    
    let defaults = UserDefaults.standard
    let enableUdpRelay = defaults.bool(forKey: "LocalSocks5.EnableUDPRelay")
    let enableVerboseMode = defaults.bool(forKey: "LocalSocks5.EnableVerboseMode")
    
    var arguments = [sslocalPath, "-c", "ss-local-config.json"]
    if enableUdpRelay {
        arguments.append("-u")
    }
    if enableVerboseMode {
        arguments.append("-v")
    }
    
    // For a complete listing of the keys, see the launchd.plist manual page.
    let dict: NSMutableDictionary = [
        "Label": "com.qiuyuzhou.shadowsocksX-NG.local",
        "WorkingDirectory": NSHomeDirectory() + APP_SUPPORT_DIR,
        "KeepAlive": true,
        "StandardOutPath": logFilePath,
        "StandardErrorPath": logFilePath,
        "ProgramArguments": arguments,
        "EnvironmentVariables": ["DYLD_LIBRARY_PATH": NSHomeDirectory() + APP_SUPPORT_DIR + "ss-local-latest/"]
    ]
    dict.write(toFile: plistFilepath, atomically: true)
    let Sha1Sum = getFileSHA1Sum(plistFilepath)
    if oldSha1Sum != Sha1Sum {
        return true
    } else {
        return false
    }
}

// 调用start_ss_local.sh脚本来开启现有的服务
func StartSSLocal() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "start_ss_local.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Start ss-local succeeded.")
    } else {
        NSLog("Start ss-local failed.")
    }
}

// 调用stop_ss_local.sh脚本来关闭现有的服务。
func StopSSLocal() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "stop_ss_local.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Stop ss-local succeeded.")
    } else {
        NSLog("Stop ss-local failed.")
    }
}

// 执行安装脚本，将需要的文件复制到对应的文件目录下。
func InstallSSLocal() {
    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir+APP_SUPPORT_DIR
    if !fileMgr.fileExists(atPath: appSupportDir + "ss-local-\(SS_LOCAL_VERSION)/ss-local")
       || !fileMgr.fileExists(atPath: appSupportDir + "ss-local-\(SS_LOCAL_VERSION)/libmbedcrypto.0.dylib") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_ss_local.sh", ofType: nil)
        let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install ss-local succeeded.")
        } else {
            NSLog("Install ss-local failed.")
        }
    }
}

// 将当前的服务器的相关参数写入到 json 文件中，并比较原有内容和现在的内容的区别。
func writeSSLocalConfFile(_ conf:[String:AnyObject]) -> Bool {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "ss-local-config.json"
        let data: Data = try JSONSerialization.data(withJSONObject: conf, options: .prettyPrinted)
        
        let oldSum = getFileSHA1Sum(filepath)
        try data.write(to: URL(fileURLWithPath: filepath), options: .atomic)
        let newSum = getFileSHA1Sum(filepath)
        
        if oldSum == newSum {
            return false
        }
        
        return true
    } catch {
        NSLog("Write ss-local file failed.")
    }
    return false
}

// 删除配置文件。
func removeSSLocalConfFile() {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "ss-local-config.json"
        try FileManager.default.removeItem(atPath: filepath)
    } catch {
        
    }
}

// 同步本地的服务器的设置
func SyncSSLocal() {
    var changed: Bool = false
    changed = changed || generateSSLocalLauchAgentPlist()
    let mgr = ServerProfileManager.instance
    if mgr.activeProfileId != nil {
        if let profile = mgr.getActiveProfile() {
            changed = changed || writeSSLocalConfFile((profile.toJsonConfig()))
        }
        
        // 判断是否正在启动状态，如果是启动状态同时状态被更改，那么进行重启。
        let on = UserDefaults.standard.bool(forKey: "ShadowsocksOn")
        if on {
            if changed {
                StopSSLocal()
                DispatchQueue.main.asyncAfter(
                    deadline: DispatchTime.now() + DispatchTimeInterval.seconds(1),
                    execute: {
                        () in
                        StartSSLocal()
                })
            } else {
                StartSSLocal()
            }
        } else {
            StopSSLocal()
        }
    } else {
        removeSSLocalConfFile()
        StopSSLocal()
    }
    SyncPac()
    SyncPrivoxy()
    SyncKcptun()
}

// --------------------------------------------------------------------------------
//  MARK: privoxy

//
func generatePrivoxyLauchAgentPlist() -> Bool {
    let privoxyPath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy"
    let logFilePath = NSHomeDirectory() + "/Library/Logs/privoxy.log"
    let launchAgentDirPath = NSHomeDirectory() + LAUNCH_AGENT_DIR
    let plistFilepath = launchAgentDirPath + LAUNCH_AGENT_CONF_PRIVOXY_NAME
    
    // Ensure launch agent directory is existed.
    let fileMgr = FileManager.default
    if !fileMgr.fileExists(atPath: launchAgentDirPath) {
        try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let oldSha1Sum = getFileSHA1Sum(plistFilepath)
    
    let arguments = [privoxyPath, "--no-daemon", "privoxy.config"]
    
    // For a complete listing of the keys, see the launchd.plist manual page.
    let dict: NSMutableDictionary = [
        "Label": "com.qiuyuzhou.shadowsocksX-NG.http",
        "WorkingDirectory": NSHomeDirectory() + APP_SUPPORT_DIR,
        "KeepAlive": true,
        "StandardOutPath": logFilePath,
        "StandardErrorPath": logFilePath,
        "ProgramArguments": arguments
    ]
    dict.write(toFile: plistFilepath, atomically: true)
    let Sha1Sum = getFileSHA1Sum(plistFilepath)
    if oldSha1Sum != Sha1Sum {
        return true
    } else {
        return false
    }
}

// 开始HTTP代理
func StartPrivoxy() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "start_privoxy.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Start privoxy succeeded.")
    } else {
        NSLog("Start privoxy failed.")
    }
}

// 停止HTTP代理
func StopPrivoxy() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "stop_privoxy.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Stop privoxy succeeded.")
    } else {
        NSLog("Stop privoxy failed.")
    }
}

// 安装HTTP代理
func InstallPrivoxy() {
    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir+APP_SUPPORT_DIR
    if !fileMgr.fileExists(atPath: appSupportDir + "privoxy-\(PRIVOXY_VERSION)/privoxy") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_privoxy.sh", ofType: nil)
        let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install privoxy succeeded.")
        } else {
            NSLog("Install privoxy failed.")
        }
    }
}

// 将对应的本地的监听相关参数写入本地文件夹中
func writePrivoxyConfFile() -> Bool {
    do {
        let defaults = UserDefaults.standard
        let bundle = Bundle.main
        let examplePath = bundle.path(forResource: "privoxy.config.example", ofType: nil)
        var example = try String(contentsOfFile: examplePath!, encoding: .utf8)
        example = example.replacingOccurrences(of: "{http}", with: defaults.string(forKey: "LocalHTTP.ListenAddress")! + ":" + String(defaults.integer(forKey: "LocalHTTP.ListenPort")))
        example = example.replacingOccurrences(of: "{socks5}", with: defaults.string(forKey: "LocalSocks5.ListenAddress")! + ":" + String(defaults.integer(forKey: "LocalSocks5.ListenPort")))
        let data = example.data(using: .utf8)
        
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy.config"
        
        let oldSum = getFileSHA1Sum(filepath)
        try data?.write(to: URL(fileURLWithPath: filepath), options: .atomic)
        let newSum = getFileSHA1Sum(filepath)
        
        if oldSum == newSum {
            return false
        }
        
        return true
    } catch {
        NSLog("Write privoxy file failed.")
    }
    return false
}

// 删除HTTP代理的本地文件
func removePrivoxyConfFile() {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy.config"
        try FileManager.default.removeItem(atPath: filepath)
    } catch {
        
    }
}

// 同步Privoxy的相关参数，如果代理是开启的状态，并且参数发生了更改的情况，那么重启。
func SyncPrivoxy() {
    var changed: Bool = false
    changed = changed || generatePrivoxyLauchAgentPlist()
    let mgr = ServerProfileManager.instance
    if mgr.activeProfileId != nil {
        changed = changed || writePrivoxyConfFile()
        
        let on = UserDefaults.standard.bool(forKey: "LocalHTTPOn")
        if on {
            if changed {
                StopPrivoxy()
                DispatchQueue.main.asyncAfter(
                    deadline: DispatchTime.now() + DispatchTimeInterval.seconds(1),
                    execute: {
                        () in
                        StartPrivoxy()
                })
            } else {
                StartPrivoxy()
            }
        } else {
            StopPrivoxy()
        }
    } else {
        removePrivoxyConfFile()
        StopPrivoxy()
    }
}

// --------------------------------------------------------------------------------
// kcptun
// 设置kcpTun的服务，并添加log文件用来记录日志文件
func generateKcptunLauchAgentPlist() -> Bool {
    let sslocalPath = NSHomeDirectory() + APP_SUPPORT_DIR + "kcptun_client"
    let logFilePath = NSHomeDirectory() + "/Library/Logs/kcptun_client.log"
    let launchAgentDirPath = NSHomeDirectory() + LAUNCH_AGENT_DIR
    let plistFilepath = launchAgentDirPath + LAUNCH_AGENT_CONF_KCPTUN_NAME
    
    // Ensure launch agent directory is existed.
    let fileMgr = FileManager.default
    if !fileMgr.fileExists(atPath: launchAgentDirPath) {
        try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let oldSha1Sum = getFileSHA1Sum(plistFilepath)
    
    var arguments = [sslocalPath, "-c", "kcptun-config.json"]
    
    let mgr = ServerProfileManager.instance
    if let profile = mgr.getActiveProfile() {
        if profile.enabledKcptun {
            let otherArgumentsLine = profile.kcptunProfile.arguments.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !otherArgumentsLine.isEmpty {
                // TOFIX: Don't support space between quotation marks
                let otherArguments = otherArgumentsLine.components(separatedBy: " ")
                arguments.append(contentsOf: otherArguments.filter { !$0.isEmpty })
            }
        }
    }
    
    // For a complete listing of the keys, see the launchd.plist manual page.
    let dict: NSMutableDictionary = [
        "Label": "com.qiuyuzhou.shadowsocksX-NG.kcptun",
        "WorkingDirectory": NSHomeDirectory() + APP_SUPPORT_DIR,
        "KeepAlive": true,
        "StandardOutPath": logFilePath,
        "StandardErrorPath": logFilePath,
        "ProgramArguments": arguments,
        "EnvironmentVariables": ["DYLD_LIBRARY_PATH": NSHomeDirectory() + APP_SUPPORT_DIR]
    ]
    dict.write(toFile: plistFilepath, atomically: true)
    let Sha1Sum = getFileSHA1Sum(plistFilepath)
    if oldSha1Sum != Sha1Sum {
        return true
    } else {
        return false
    }
}

// 安装kcptun服务 复制相关文件
func InstallKcptunClient() {
    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir+APP_SUPPORT_DIR
    if !fileMgr.fileExists(atPath: appSupportDir + "kcptun_\(KCPTUN_CLIENT_VERSION)/kcptun_client") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_kcptun", ofType: "sh")
        let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install kcptun succeeded.")
        } else {
            NSLog("Install kcptun failed.")
        }
    }
}

// 添加Kcptun配置文件。
func writeKcptunConfFile(_ conf:[String:AnyObject]) -> Bool {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "kcptun-config.json"
        let data: Data = try JSONSerialization.data(withJSONObject: conf, options: .prettyPrinted)
        
        let oldSum = getFileSHA1Sum(filepath)
        try data.write(to: URL(fileURLWithPath: filepath), options: .atomic)
        let newSum = getFileSHA1Sum(filepath)
        
        if oldSum == newSum {
            return false
        }
        
        return true
    } catch {
        NSLog("Write kcptun config file failed.")
    }
    return false
}

// 返回是否开启kcptun服务
func isEnabledKcptun() -> Bool {
    let mgr = ServerProfileManager.instance
    if let profile = mgr.getActiveProfile() {
        return profile.enabledKcptun
    }
    return false
}

// 删除kcptun配置文件
func removeKcptunConfFile() {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "kcptun-config.json"
        try FileManager.default.removeItem(atPath: filepath)
    } catch {
        
    }
}

// 开启kcptun文件
func StartKcptun() {
    if isEnabledKcptun() {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "start_kcptun.sh", ofType: nil)
        let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Start kcptun succeeded.")
        } else {
            NSLog("Start kcptun failed.")
        }
    }
}

// 停止kcptun文件
func StopKcptun() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "stop_kcptun.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Stop kcptun succeeded.")
    } else {
        NSLog("Stop kcptun failed.")
    }
}

// 同步Kcptun相关参数，并重启服务。
func SyncKcptun() {
    var changed: Bool = false
    changed = changed || generateKcptunLauchAgentPlist()
    let mgr = ServerProfileManager.instance
    if let profile = mgr.getActiveProfile() {
        if profile.enabledKcptun {
            changed = changed || writeKcptunConfFile(profile.toKcptunJsonConfig())
            
            let on = UserDefaults.standard.bool(forKey: "ShadowsocksOn")
            if on {
                if changed {
                    StopKcptun()
                    DispatchQueue.main.asyncAfter(
                        deadline: DispatchTime.now() + DispatchTimeInterval.seconds(1),
                        execute: {
                            () in
                            StartKcptun()
                    })
                } else {
                    StartKcptun()
                }
            } else {
                StopKcptun()
            }
            return
        }
    }
    StopKcptun()
    removeKcptunConfFile()
}
