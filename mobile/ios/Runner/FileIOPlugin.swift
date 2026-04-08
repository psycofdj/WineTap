import Flutter
import UIKit
import UniformTypeIdentifiers

@available(iOS 14.0, *)
class FileIOPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
    private var pendingResult: FlutterResult?
    private var pendingAction: String?
    private var pendingData: Data?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.winetap.mobile/file_io",
            binaryMessenger: registrar.messenger()
        )
        let instance = FileIOPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "pickFileBytes":
            pickFile(result: result)
        case "saveFile":
            guard let args = call.arguments as? [String: Any],
                  let bytes = args["bytes"] as? FlutterStandardTypedData,
                  let name = args["name"] as? String else {
                result(FlutterError(code: "invalid_argument", message: "bytes and name are required", details: nil))
                return
            }
            saveFile(data: bytes.data, name: name, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func pickFile(result: @escaping FlutterResult) {
        pendingResult = result
        pendingAction = "pick"

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data])
        picker.delegate = self
        picker.allowsMultipleSelection = false

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            result(FlutterError(code: "no_view_controller", message: "Cannot present picker", details: nil))
            return
        }
        viewController.present(picker, animated: true)
    }

    private func saveFile(data: Data, name: String, result: @escaping FlutterResult) {
        pendingResult = result
        pendingAction = "save"
        pendingData = data

        // Write to a temp file so UIDocumentPickerViewController can export it.
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: tempURL)
        } catch {
            result(FlutterError(code: "write_failed", message: error.localizedDescription, details: nil))
            return
        }

        let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
        picker.delegate = self

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            result(FlutterError(code: "no_view_controller", message: "Cannot present picker", details: nil))
            return
        }
        viewController.present(picker, animated: true)
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let result = pendingResult else { return }
        let action = pendingAction
        pendingResult = nil
        pendingAction = nil
        pendingData = nil

        if action == "pick" {
            guard let url = urls.first else {
                result(nil)
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                result(FlutterError(code: "access_denied", message: "Cannot access file", details: nil))
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                result(FlutterStandardTypedData(bytes: data))
            } catch {
                result(FlutterError(code: "read_failed", message: error.localizedDescription, details: nil))
            }
        } else if action == "save" {
            result(true)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pendingResult?(nil)
        pendingResult = nil
        pendingAction = nil
        pendingData = nil
    }
}
