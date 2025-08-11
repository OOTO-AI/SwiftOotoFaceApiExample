import UIKit

final class ViewController: UIViewController {
    // MARK: - Outlets
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var resultLabel: UILabel!

    @IBOutlet weak var takePhotoButton: UIButton!
    @IBOutlet weak var enrollButton: UIButton!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!

    // MARK: - State
    private var lastCapturedImage: UIImage?
    private var lastTemplateId: String?

    private let spinner = UIActivityIndicatorView(style: .large)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // UI base
        view.backgroundColor = .systemBackground

        resultLabel.text = ""
        resultLabel.numberOfLines = 0
        resultLabel.lineBreakMode = .byCharWrapping
        resultLabel.adjustsFontSizeToFitWidth = false
        resultLabel.isOpaque = false
        resultLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        styleButton(takePhotoButton)
        styleButton(enrollButton)
        styleButton(searchButton)
        styleDestructive(deleteButton)

        // Initial state
        enrollButton.isEnabled = false
        searchButton.isEnabled = false
        deleteButton.isHidden = true
        deleteButton.isEnabled = false

        // Actions
        takePhotoButton.addTarget(self, action: #selector(didTapTakePhoto), for: .touchUpInside)
        enrollButton.addTarget(self, action: #selector(didTapEnroll), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(didTapSearch), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)

        // Spinner
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Actions
    @objc private func didTapTakePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            setStatus("Camera not available")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func didTapEnroll() {
        guard let image = lastCapturedImage else {
            setStatus("No photo")
            return
        }
        beginNetwork("Enrolling...")
        APIClient.shared.enroll(image: image, customTemplateId: nil) { [weak self] res in
            DispatchQueue.main.async {
                self?.endNetwork()
                switch res {
                case .success(let templateId):
                    self?.lastTemplateId = templateId.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.setStatus("Enrolled\nTemplate ID:\n\(self?.lastTemplateId ?? "")")
                    self?.updateDeleteVisibility()
                case .failure(let error):
                    self?.setStatus(Self.humanReadable(error: error))
                }
            }
        }
    }

    @objc private func didTapSearch() {
        guard let image = lastCapturedImage else {
            setStatus("No photo")
            return
        }
        beginNetwork("Searching...")
        APIClient.shared.identify(image: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.endNetwork()
                switch result {
                case .success(let info):
                    let tid = info.templateId.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.lastTemplateId = tid
                    self?.setStatus("""
                    Match:
                    \(tid)
                    Similarity: \(String(format: "%.2f", info.similarity))
                    """)
                    self?.updateDeleteVisibility()
                case .failure(let error):
                    self?.setStatus(Self.humanReadable(error: error))
                }
            }
        }
    }

    @objc private func didTapDelete() {
        guard let tid = lastTemplateId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !tid.isEmpty else { return }

        beginNetwork("Deleting...")
        APIClient.shared.deleteTemplate(templateId: tid) { [weak self] res in
            DispatchQueue.main.async {
                self?.endNetwork()
                switch res {
                case .success:
                    self?.setStatus("Deleted\nTemplate ID:\n\(tid)")
                    self?.lastTemplateId = nil
                    self?.updateDeleteVisibility()
                case .failure(let error):
                    self?.setStatus("Delete failed: \(Self.humanReadable(error: error))")
                }
            }
        }
    }

    // MARK: - UI helpers
    private func styleButton(_ b: UIButton) {
        b.layer.cornerRadius = 12
        b.layer.masksToBounds = true
        b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        b.backgroundColor = .systemBlue
        b.setTitleColor(.white, for: .normal)
        b.setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)
    }

    private func styleDestructive(_ b: UIButton) {
        styleButton(b)
        b.backgroundColor = .systemRed
    }

    private func setStatus(_ text: String) {
        resultLabel.text = text
    }

    private func beginNetwork(_ status: String) {
        setStatus(status)
        spinner.startAnimating()
        view.isUserInteractionEnabled = false
        takePhotoButton.isEnabled = false
        enrollButton.isEnabled = false
        searchButton.isEnabled = false
        deleteButton.isEnabled = false
    }

    private func endNetwork() {
        spinner.stopAnimating()
        view.isUserInteractionEnabled = true
        takePhotoButton.isEnabled = true
        enrollButton.isEnabled = (lastCapturedImage != nil)
        searchButton.isEnabled = (lastCapturedImage != nil)
        updateDeleteVisibility()
    }

    private func updateDeleteVisibility() {
        let hasTid = (lastTemplateId?.isEmpty == false)
        deleteButton.isHidden = !hasTid
        deleteButton.isEnabled = hasTid
    }

    private static func humanReadable(error: APIError) -> String {
        switch error {
        case .server(_, let message, _): return message
        case .network(let err):         return "Network error: \(err.localizedDescription)"
        case .decoding:                 return "Decoding error"
        case .invalidResponse(let msg): return msg
        default:                        return "Unknown error"
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            photoImageView.image = image
            lastCapturedImage = image
            enrollButton.isEnabled = true
            searchButton.isEnabled = true
            lastTemplateId = nil
            updateDeleteVisibility()
            setStatus("Ready")
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
