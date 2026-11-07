// Creator Studio 아이폰 앱(에이스 2026-11-07, 혼자 쓰는 용도). 안드로이드 앱과 같은 화면(app/index.html)을 쓴다.
// - 앱 화면: 카드뉴스·쓰레드 글·메모를 폰 혼자 만든다(Claude·Kie·노션·텔레그램을 이 앱이 직접 부른다).
// - PC 화면: 집 PC Creator Studio의 휴대폰 화면(업로드·수익)을 따로 연다.
// 자바스크립트 ↔ 앱 연결은 prompt()로 한다(바로 답을 돌려줘야 하는 get 같은 것 때문에).
import UIKit
import WebKit
import AVFoundation
import Photos

let BG = UIColor(red: 16/255, green: 18/255, blue: 23/255, alpha: 1)
let HOSTS = ["api.anthropic.com", "api.kie.ai", "api.notion.com", "api.telegram.org"]
let MARK = "__cs__"

let SHIM_APP = """
(function(){function c(f,a){var r=prompt("__cs__",JSON.stringify({fn:f,args:a}));return r==null?"":r}
window.CSApp={get:function(k){return c("get",[k])},set:function(k,v){c("set",[k,String(v)])},pcUrl:function(){return c("pcUrl",[])},
setPcUrl:function(u){c("setPcUrl",[u])},openPc:function(){c("openPc",[])},openUrl:function(u){c("openUrl",[u])},
copy:function(t){return c("copy",[String(t)])==="1"},pasteText:function(){return c("pasteText",[])},shareText:function(t){c("shareText",[String(t)])},
saveShare:function(n,m,b,t){return c("saveShare",[n,m,b,t||""])},save:function(n,m,b){return c("save",[n,m,b])},
makeReel:function(id,n,b,s){c("makeReel",[id,n,b,!!s])},http:function(id,s){c("http",[id,s])},reset:function(){c("reset",[])}};})();
"""
let SHIM_PC = """
(function(){function c(f,a){var r=prompt("__cs__",JSON.stringify({fn:f,args:a}));return r==null?"":r}
window.CSApp={copy:function(t){return c("copy",[String(t)])==="1"},save:function(n,m,b){return c("save",[n,m,b])},reset:function(){c("reset",[])}};})();
"""

final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = MainController()
        w.backgroundColor = BG
        w.makeKeyAndVisible()
        window = w
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // creatorstudio://open?u=<PC 링크>
        if let main = window?.rootViewController as? MainController,
           let u = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "u" })?.value {
            main.setPc(u)
            main.showPc()
        }
        return true
    }
}

final class MainController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    var app: WKWebView!
    var pc: WKWebView!
    let back = UIButton(type: .system)
    var pcLoaded = ""
    let defaults = UserDefaults.standard

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = BG
        app = makeWeb(SHIM_APP)
        pc = makeWeb(SHIM_PC)
        pc.isHidden = true
        for w in [app!, pc!] {
            view.addSubview(w)
            w.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                w.leadingAnchor.constraint(equalTo: view.leadingAnchor), w.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                w.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), w.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        }
        back.setTitle("‹ 앱", for: .normal)
        back.setTitleColor(.white, for: .normal)
        back.backgroundColor = UIColor(red: 40/255, green: 44/255, blue: 54/255, alpha: 0.85)
        back.layer.cornerRadius = 10
        back.isHidden = true
        back.addTarget(self, action: #selector(showApp), for: .touchUpInside)
        view.addSubview(back)
        back.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            back.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -70),
            back.widthAnchor.constraint(equalToConstant: 64), back.heightAnchor.constraint(equalToConstant: 36)])
        if let page = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "app") {
            app.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
    }

    func makeWeb(_ shim: String) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.addUserScript(WKUserScript(source: shim, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        cfg.allowsInlineMediaPlayback = true
        cfg.applicationNameForUserAgent = "CreatorStudioApp/2.0"
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.uiDelegate = self
        w.navigationDelegate = self
        w.isOpaque = false
        w.backgroundColor = BG
        w.scrollView.backgroundColor = BG
        return w
    }

    // MARK: 화면 바꾸기

    func setPc(_ raw: String) {
        defaults.set(MainController.normalize(raw) ?? "", forKey: "pc_url")
        pcLoaded = ""
    }

    func showPc() {
        let url = defaults.string(forKey: "pc_url") ?? ""
        guard !url.isEmpty, let u = URL(string: url) else {
            toast("PC 주소가 없어요. 설정에서 넣어 주세요")
            showApp(); run("CS.go('settings')")
            return
        }
        app.isHidden = true; pc.isHidden = false; back.isHidden = false
        if pcLoaded != url { pcLoaded = url; pc.load(URLRequest(url: u)) }
    }

    @objc func showApp() {
        pc.isHidden = true; back.isHidden = true; app.isHidden = false
    }

    static func normalize(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = t.range(of: "https?://[^\\s<>\"']+", options: .regularExpression) { return String(t[r]) }
        if t.range(of: "^[0-9a-zA-Z.\\-]+(:\\d+)?(/.*)?$", options: .regularExpression) != nil && t.contains(".") { return "http://" + t }
        return nil
    }

    func run(_ js: String) {
        DispatchQueue.main.async { self.app.evaluateJavaScript(js, completionHandler: nil) }
    }

    func done(_ id: String, _ obj: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: obj), let json = String(data: data, encoding: .utf8),
              let idData = try? JSONSerialization.data(withJSONObject: [id]), let idArr = String(data: idData, encoding: .utf8) else { return }
        run("CS._done(\(idArr)[0],\(json))")
    }

    func toast(_ s: String) {
        DispatchQueue.main.async {
            let l = UILabel()
            l.text = "  " + s + "  "
            l.textColor = .white
            l.backgroundColor = UIColor(white: 0.15, alpha: 0.95)
            l.layer.cornerRadius = 10; l.clipsToBounds = true
            l.numberOfLines = 0; l.textAlignment = .center
            self.view.addSubview(l)
            l.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([l.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                                         l.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -110),
                                         l.widthAnchor.constraint(lessThanOrEqualTo: self.view.widthAnchor, constant: -40),
                                         l.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)])
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { l.removeFromSuperview() }
        }
    }

    // MARK: 자바스크립트 → 앱

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        guard prompt == MARK, let text = defaultText, let data = text.data(using: .utf8),
              let call = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fn = call["fn"] as? String else {
            completionHandler(nil); return
        }
        let a = (call["args"] as? [Any]) ?? []
        func s(_ i: Int) -> String { i < a.count ? ((a[i] as? String) ?? String(describing: a[i])) : "" }
        let isApp = webView === app
        if !isApp && !["copy", "save", "reset"].contains(fn) { completionHandler(""); return }
        switch fn {
        case "get": completionHandler(defaults.string(forKey: "v:" + s(0)) ?? "")
        case "set": defaults.set(s(1), forKey: "v:" + s(0)); completionHandler("")
        case "pcUrl": completionHandler(defaults.string(forKey: "pc_url") ?? "")
        case "setPcUrl": setPc(s(0)); completionHandler("")
        case "openPc": completionHandler(""); DispatchQueue.main.async { self.showPc() }
        case "openUrl": completionHandler(""); if let u = URL(string: s(0)) { UIApplication.shared.open(u) }
        case "copy": UIPasteboard.general.string = s(0); completionHandler("1")
        case "pasteText": completionHandler(UIPasteboard.general.string ?? "")
        case "shareText": completionHandler(""); share([s(0)])
        case "save": completionHandler(save(s(0), s(1), s(2), share: false, text: ""))
        case "saveShare": completionHandler(save(s(0), s(1), s(2), share: true, text: s(3)))
        case "reset": completionHandler(""); DispatchQueue.main.async { self.showApp(); self.run("CS.go('settings')") }
        case "makeReel":
            completionHandler("")
            let id = s(0), name = s(1), b64 = s(2), thenShare = (a.count > 3 && (a[3] as? Bool) == true)
            DispatchQueue.global().async { self.reel(id, name, b64, thenShare) }
        case "http":
            completionHandler("")
            http(s(0), s(1))
        default: completionHandler("")
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    // 링크: 앱 화면은 자기 파일만, PC 화면은 PC 주소만 안에서 연다. 나머지는 사파리 등으로.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.allow); return }
        if url.isFileURL || url.scheme == "about" || url.scheme == "blob" || url.scheme == "data" { decisionHandler(.allow); return }
        if webView === pc, let home = URL(string: defaults.string(forKey: "pc_url") ?? ""), url.host == home.host { decisionHandler(.allow); return }
        if action.targetFrame?.isMainFrame == false { decisionHandler(.allow); return }
        decisionHandler(.cancel)
        UIApplication.shared.open(url)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard webView === pc else { return }
        pcLoaded = ""
        let why = error.localizedDescription.replacingOccurrences(of: "<", with: "")
        pc.loadHTMLString("""
        <html><head><meta name=viewport content='width=device-width,initial-scale=1'></head><body style='background:#101217;color:#eceef2;font-family:-apple-system,sans-serif;padding:28px'>
        <h2>PC에 연결하지 못했어요</h2><p style='color:#9aa1ad;line-height:1.6'>· PC와 Creator Studio가 켜져 있어야 해요.<br>
        · PC를 다시 켰거나 업데이트됐다면 밖 주소가 바뀌었어요. 텔레그램으로 온 새 링크를 복사해서 앱 ⚙ 설정의 '붙여넣기'로 바꿔 주세요.<br>
        · 카드뉴스·쓰레드 글·메모는 PC 없이 앱에서 바로 돼요(왼쪽 아래 '‹ 앱').</p><p style='color:#666'>(\(why))</p>
        <button onclick="location.href='\(defaults.string(forKey: "pc_url") ?? "")'" style='padding:12px 18px;border:0;border-radius:10px;background:#ff5a66;color:#fff;font-size:16px'>다시 시도</button></body></html>
        """, baseURL: nil)
    }

    // MARK: 저장·공유

    func folder() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("CreatorStudio")
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        return docs
    }

    func save(_ name: String, _ mime: String, _ b64: String, share: Bool, text: String) -> String {
        guard let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else { return "저장하지 못했어요(데이터 오류)" }
        let safe = name.replacingOccurrences(of: "[\\\\/:*?\"<>|]", with: "_", options: .regularExpression)
        let file = folder().appendingPathComponent(safe)
        do { try data.write(to: file) } catch { return "저장하지 못했어요: \(error.localizedDescription)" }
        if share {
            var items: [Any] = [file]
            if !text.isEmpty { items.append(text) }
            self.share(items)
            return "저장했어요"
        }
        if mime.hasPrefix("image/") || mime.hasPrefix("video/") { toPhotos(file, video: mime.hasPrefix("video/")); return "사진 앱과 파일 앱(Creator Studio)에 저장했어요" }
        return "파일 앱 > 나의 iPhone > Creator Studio에 저장했어요"
    }

    func toPhotos(_ file: URL, video: Bool) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { self.toast("사진 앱 저장을 허용해 주세요(설정 > Creator Studio > 사진)"); return }
            PHPhotoLibrary.shared().performChanges({
                if video { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: file) }
                else { PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: file) }
            }, completionHandler: nil)
        }
    }

    func share(_ items: [Any]) {
        DispatchQueue.main.async {
            let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = self.view
            self.present(vc, animated: true)
        }
    }

    // MARK: 릴스(카드 한 장 → 8초 1080x1920 mp4)

    func reel(_ id: String, _ name: String, _ b64: String, _ thenShare: Bool) {
        do {
            guard let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters), let card = UIImage(data: data)?.cgImage else {
                throw NSError(domain: "cs", code: 1, userInfo: [NSLocalizedDescriptionKey: "카드 그림을 읽지 못했어요"])
            }
            let file = folder().appendingPathComponent(name)
            try? FileManager.default.removeItem(at: file)
            try Reel.encode(card, to: file, seconds: 8, fps: 30)
            toPhotos(file, video: true)
            if thenShare { share([file]) }
            done(id, ["ok": true])
        } catch {
            done(id, ["ok": false, "error": error.localizedDescription])
        }
    }

    // MARK: 정해진 곳에만 HTTP

    func allowed(_ url: URL, binary: Bool) -> Bool {
        let host = (url.host ?? "").lowercased()
        if let pcHost = URL(string: defaults.string(forKey: "pc_url") ?? "")?.host?.lowercased(), host == pcHost { return true }
        if url.scheme != "https" { return false }
        if HOSTS.contains(host) { return true }
        return binary
    }

    func http(_ id: String, _ specJson: String) {
        guard let data = specJson.data(using: .utf8), let spec = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let u = spec["url"] as? String, let url = URL(string: u) else { done(id, ["status": 0, "error": "요청이 잘못됐어요"]); return }
        let binary = (spec["binary"] as? Bool) ?? false
        if !allowed(url, binary: binary) { done(id, ["status": 0, "error": "허용되지 않은 주소예요: \(url.host ?? "")"]); return }
        var req = URLRequest(url: url)
        req.httpMethod = (spec["method"] as? String) ?? "GET"
        req.timeoutInterval = Double((spec["timeout"] as? Int) ?? 300000) / 1000
        for (k, v) in (spec["headers"] as? [String: Any]) ?? [:] { req.setValue("\(v)", forHTTPHeaderField: k) }
        if let multi = spec["multipart"] as? [String: Any] {
            let boundary = "----cs\(UInt64(Date().timeIntervalSince1970 * 1000))"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            func add(_ s: String) { body.append(s.data(using: .utf8)!) }
            for (k, v) in (multi["fields"] as? [String: Any]) ?? [:] {
                add("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(k)\"\r\n\r\n\(v)\r\n")
            }
            for f in (multi["files"] as? [[String: Any]]) ?? [] {
                let fname = ((f["filename"] as? String) ?? "file").replacingOccurrences(of: "\"", with: "")
                add("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(f["field"] ?? "file")\"; filename=\"\(fname)\"\r\nContent-Type: \((f["mime"] as? String) ?? "application/octet-stream")\r\n\r\n")
                body.append(Data(base64Encoded: (f["base64"] as? String) ?? "", options: .ignoreUnknownCharacters) ?? Data())
                add("\r\n")
            }
            add("--\(boundary)--\r\n")
            req.httpBody = body
        } else if let body = spec["body"] as? String {
            req.httpBody = body.data(using: .utf8)
        }
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { self.done(id, ["status": 0, "error": err.localizedDescription]); return }
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let d = data ?? Data()
            if binary && status < 400 { self.done(id, ["status": status, "base64": d.base64EncodedString()]) }
            else { self.done(id, ["status": status, "text": String(data: d, encoding: .utf8) ?? ""]) }
        }.resume()
    }
}

enum Reel {
    static let W = 1080, H = 1920

    static func encode(_ card: CGImage, to file: URL, seconds: Int, fps: Int32) throws {
        let writer = try AVAssetWriter(outputURL: file, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000]])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? NSError(domain: "cs", code: 2) }
        writer.startSession(atSourceTime: .zero)
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, W, H, kCVPixelFormatType_32BGRA, [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &pb)
        guard let buffer = pb else { throw NSError(domain: "cs", code: 3) }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: W, height: H, bitsPerComponent: 8,
                               bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
            let ch = Double(card.height) * Double(W) / Double(card.width)
            ctx.interpolationQuality = .high
            ctx.draw(card, in: CGRect(x: 0, y: (Double(H) - ch) / 2, width: Double(W), height: ch))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        let frames = Int64(seconds) * Int64(fps)
        var i: Int64 = 0
        while i < frames {
            if input.isReadyForMoreMediaData {
                adaptor.append(buffer, withPresentationTime: CMTime(value: i, timescale: fps))
                i += 1
            } else {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        input.markAsFinished()
        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        sem.wait()
        if writer.status != .completed { throw writer.error ?? NSError(domain: "cs", code: 4, userInfo: [NSLocalizedDescriptionKey: "영상을 만들지 못했어요"]) }
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
