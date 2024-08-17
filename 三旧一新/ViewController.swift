import UIKit
import WebKit

class ViewController: UIViewController, UIScrollViewDelegate, WKScriptMessageHandler {

    // 连接到 Storyboard 中的 WKWebView 和 UIView
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var yourView: UIView!

    // 记录上次触发震动的位置
    var lastContentOffset: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 加载离线页面
        loadOfflinePage()
        
        // 根据系统外观模式更新视图背景颜色
        updateViewBackgroundColor()

        // 如果当前设备是 iPad，则添加新建窗口按钮
        if UIDevice.current.userInterfaceIdiom == .pad {
            let newWindowButton = UIBarButtonItem(title: "New Window", style: .plain, target: self, action: #selector(openNewWindow))
            navigationItem.rightBarButtonItem = newWindowButton
        }

        // 添加左滑手势识别器，并绑定到 handleSwipe 方法
        let leftSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        leftSwipeGesture.direction = .left
        view.addGestureRecognizer(leftSwipeGesture)
        
        // 添加右滑手势识别器，并绑定到 handleSwipe 方法
        let rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        rightSwipeGesture.direction = .right
        view.addGestureRecognizer(rightSwipeGesture)
        
        // 设置 WebView 的 UIScrollView 代理
        webView.scrollView.delegate = self
        
        // 为页面上的所有按钮添加振动反馈
        addHapticFeedbackToButtons()
    }

    // 处理滑动手势，根据滑动方向触发不同的振动反馈并加载相应的页面
    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left {
            // 左滑时触发成功振动反馈，并导航到下一页
            triggerNotificationFeedback(type: .success)
            webView.evaluateJavaScript("document.querySelector('.day1 a:nth-child(3)').click();", completionHandler: nil)
        } else if gesture.direction == .right {
            // 右滑时触发警告振动反馈，并导航到上一页
            triggerNotificationFeedback(type: .warning)
            webView.evaluateJavaScript("document.querySelector('.day1 a:nth-child(1)').click();", completionHandler: nil)
        }
    }

    // 当用户滚动时，检查是否到达顶部或底部
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height
        
        // 如果滚动到顶部或底部且与上次位置不同，则触发一次强烈的震动
        if offsetY <= 0 && lastContentOffset > 0 {
            triggerStrongHapticFeedback() // 顶部
        } else if offsetY >= contentHeight - frameHeight && lastContentOffset < contentHeight - frameHeight {
            triggerStrongHapticFeedback() // 底部
        }
        
        // 记录当前滚动位置
        lastContentOffset = offsetY
    }

    // 强力的振动反馈
    func triggerStrongHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    // 振动反馈方法，根据传入的类型触发相应的反馈
    func triggerNotificationFeedback(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    // 加载本地 HTML 文件（indexRL.html）
    func loadOfflinePage() {
        if let filePath = Bundle.main.path(forResource: "indexRL", ofType: "html") {
            let fileURL = URL(fileURLWithPath: filePath)
            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL)
        }
    }

    // 为页面上的所有按钮添加振动反馈
    func addHapticFeedbackToButtons() {
        let jsCode = """
        document.querySelectorAll('button').forEach(button => {
            button.addEventListener('click', function() {
                window.webkit.messageHandlers.hapticFeedback.postMessage('buttonClicked');
            });
        });
        """
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }

    // 处理来自 JavaScript 的消息，触发按钮点击时的振动反馈
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "hapticFeedback" && message.body as? String == "buttonClicked" {
            triggerNotificationFeedback(type: .success) // 按钮点击时的振动反馈
        }
    }

    // 设置支持的屏幕方向，支持所有方向但不包括倒立
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .allButUpsideDown
    }

    // 在视图布局子视图时调整 WebView 和 yourView 的大小
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        webView.frame = view.bounds
        
        let screenWidth = UIScreen.main.bounds.width
        
        // 根据设备类型调整 yourView 的大小
        if UIDevice.current.userInterfaceIdiom == .pad {
            yourView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: 23)
        } else if UIDevice.current.userInterfaceIdiom == .phone, let window = view.window {
            let topInset = window.safeAreaInsets.top
            if topInset == 20 {
                yourView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: 20)
            } else {
                yourView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: 50)
            }
        }
    }

    // 在设备旋转时调整视图布局和显示状态
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // 在旋转动画期间调整 WebView 的大小
        coordinator.animate(alongsideTransition: { _ in
            self.webView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            
            // 如果是横屏，隐藏 yourView；否则在非 iPad 设备上显示 yourView
            if UIDevice.current.orientation.isLandscape {
                self.yourView.isHidden = true
            } else {
                if UIDevice.current.userInterfaceIdiom != .pad {
                    self.yourView.isHidden = false
                }
            }
        }, completion: { _ in
            // 旋转完成后，确保 WebView 填充整个视图
            self.webView.frame = self.view.bounds
        })
    }

    // 根据系统外观模式更新 yourView 的背景颜色
    func updateViewBackgroundColor() {
        if traitCollection.userInterfaceStyle == .dark {
            yourView.backgroundColor = UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1.0) // 深色模式背景颜色
        } else {
            yourView.backgroundColor = UIColor(red: 0.933, green: 0.906, blue: 0.824, alpha: 1.0) // 浅色模式背景颜色
        }
    }

    // 当系统外观模式发生变化时调用，更新 yourView 的背景颜色
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateViewBackgroundColor()
        }
    }

    // 打开新窗口的操作（仅在 iPad 上可用）
    @objc func openNewWindow() {
        if UIApplication.shared.connectedScenes.first is UIWindowScene {
            let options = UIWindowScene.ActivationRequestOptions()
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: options, errorHandler: nil)
        }
    }
}
