import UIKit
import WebKit

final class ViewController: UIViewController, WKNavigationDelegate {
    private let webView = WKWebView(frame: .zero)
    private let statusLabel = UILabel()
    private let preview = UIImageView()
    private let captureButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private var snapshotURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "WKWebView Snapshot Repro"
        configureUI()
        configureOffscreenWebView()
        loadFixture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = CGSize(width: 320, height: 240)
        webView.frame = CGRect(x: -size.width - 8, y: 0, width: size.width, height: size.height)
    }

    private func configureUI() {
        let instructions = UILabel()
        instructions.numberOfLines = 0
        instructions.font = .preferredFont(forTextStyle: .body)
        instructions.text = "1. Run on a physical iPhone.\n2. Start Apple iPhone Mirroring on the Mac.\n3. Tap Capture Snapshot.\n\nThe WKWebView is attached to this view controller but positioned just outside the visible bounds."

        statusLabel.numberOfLines = 0
        statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        statusLabel.text = "Loading local HTML…"

        preview.contentMode = .scaleAspectFit
        preview.backgroundColor = UIColor(white: 0.85, alpha: 1)
        preview.layer.borderColor = UIColor.separator.cgColor
        preview.layer.borderWidth = 1
        preview.layer.cornerRadius = 8
        preview.clipsToBounds = true
        preview.heightAnchor.constraint(equalToConstant: 240).isActive = true

        captureButton.configuration = .filled()
        captureButton.setTitle("Capture Snapshot", for: .normal)
        captureButton.isEnabled = false
        captureButton.addTarget(self, action: #selector(capture), for: .touchUpInside)

        shareButton.setTitle("Share PNG", for: .normal)
        shareButton.isEnabled = false
        shareButton.addTarget(self, action: #selector(share), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [captureButton, shareButton])
        buttons.axis = .horizontal
        buttons.spacing = 12
        buttons.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [instructions, buttons, statusLabel, preview])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
        ])
    }

    private func configureOffscreenWebView() {
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false
        view.addSubview(webView)
        view.sendSubviewToBack(webView)
    }

    private func loadFixture() {
        webView.loadHTMLString(
            """
            <!doctype html>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; }
              body {
                display: grid;
                place-items: center;
                color: white;
                background: linear-gradient(135deg, #ff2d55, #5856d6);
                font: 700 28px -apple-system, sans-serif;
              }
              div { padding: 24px; border: 4px solid white; border-radius: 24px; }
            </style>
            <div>WKWebView snapshot</div>
            """,
            baseURL: nil
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        statusLabel.text = "Local HTML loaded. Ready to capture."
        captureButton.isEnabled = true
    }

    @objc private func capture() {
        captureButton.isEnabled = false
        statusLabel.text = "Capturing…"

        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds
        configuration.afterScreenUpdates = true

        webView.takeSnapshot(with: configuration) { [weak self] image, error in
            guard let self else { return }
            self.captureButton.isEnabled = true

            if let error {
                self.statusLabel.text = "FAILED\nerror=\(error)"
                return
            }
            guard let image, let png = image.pngData() else {
                self.statusLabel.text = "FAILED\nimage or PNG data is nil"
                return
            }

            let transparent = image.isFullyTransparent
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("wkwebview-snapshot-\(Int(Date().timeIntervalSince1970)).png")
            do {
                try png.write(to: url, options: .atomic)
                self.snapshotURL = url
                self.shareButton.isEnabled = true
            } catch {
                self.snapshotURL = nil
                self.shareButton.isEnabled = false
            }

            self.preview.image = image
            self.statusLabel.text = """
            completion error: nil
            image size: \(Int(image.size.width))×\(Int(image.size.height)) pt
            PNG bytes: \(png.count)
            fully transparent: \(transparent ? "YES — BUG REPRODUCED" : "NO — normal image")
            """
        }
    }

    @objc private func share() {
        guard let snapshotURL else { return }
        present(UIActivityViewController(activityItems: [snapshotURL], applicationActivities: nil), animated: true)
    }
}

private extension UIImage {
    var isFullyTransparent: Bool {
        guard let cgImage else { return false }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: pixels.count, by: 4).allSatisfy { pixels[$0] == 0 }
    }
}
