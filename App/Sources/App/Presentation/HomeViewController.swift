// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import UIKit
import Combine
import Core

final class HomeViewController: UIViewController {
    private let viewModel: HomeViewModel
    private var cancellables = Set<AnyCancellable>()

    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let connectTapSubject = PassthroughSubject<Void, Never>()
    private let disconnectTapSubject = PassthroughSubject<Void, Never>()
    private let openCaptionsTapSubject = PassthroughSubject<Void, Never>()
    private let endCaptionsTapSubject = PassthroughSubject<Void, Never>()
    private let unlinkTapSubject = PassthroughSubject<Void, Never>()
    private let deviceSelectedSubject = PassthroughSubject<HallidayDiscoveredDevice, Never>()

    private var discoveredDevices: [HallidayDiscoveredDevice] = []

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alwaysBounceVertical = true
        return view
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }()

    private let stateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.text = "State: -"
        return label
    }()

    private let linkedTargetLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.text = "No linked target"
        return label
    }()

    private let connectButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Scan / Connect", for: .normal)
        return button
    }()

    private let disconnectButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Disconnect", for: .normal)
        return button
    }()

    private let unlinkButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Unlink", for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        return button
    }()

    private let openCaptionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Open Captions", for: .normal)
        button.isEnabled = false
        return button
    }()

    private let endCaptionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("End Captions", for: .normal)
        button.isEnabled = false
        return button
    }()

    private let devicesTableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.layer.cornerRadius = 10
        return table
    }()

    private let devicesTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.text = "Service Devices (Tap To Link Target)"
        return label
    }()

    private let logsTextView: UITextView = {
        let view = UITextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isEditable = false
        view.isScrollEnabled = true
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 10
        return view
    }()

    private let transcriptTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.text = "Live Transcript"
        return label
    }()

    private let transcriptTextView: UITextView = {
        let view = UITextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isEditable = false
        view.isScrollEnabled = true
        view.font = .systemFont(ofSize: 14, weight: .regular)
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 10
        view.text = "Waiting for speech..."
        return view
    }()

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        buildLayout()
        bindViewModel()

        devicesTableView.dataSource = self
        devicesTableView.delegate = self

        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        disconnectButton.addTarget(self, action: #selector(disconnectTapped), for: .touchUpInside)
        openCaptionsButton.addTarget(self, action: #selector(openCaptionsTapped), for: .touchUpInside)
        endCaptionsButton.addTarget(self, action: #selector(endCaptionsTapped), for: .touchUpInside)
        unlinkButton.addTarget(self, action: #selector(unlinkTapped), for: .touchUpInside)

        viewDidLoadSubject.send(())
    }

    private func bindViewModel() {
        let input = HomeViewModel.Input(
            viewDidLoadIn: viewDidLoadSubject.eraseToAnyPublisher(),
            connectTapIn: connectTapSubject.eraseToAnyPublisher(),
            disconnectTapIn: disconnectTapSubject.eraseToAnyPublisher(),
            openCaptionsTapIn: openCaptionsTapSubject.eraseToAnyPublisher(),
            endCaptionsTapIn: endCaptionsTapSubject.eraseToAnyPublisher(),
            unlinkTapIn: unlinkTapSubject.eraseToAnyPublisher(),
            deviceSelectedIn: deviceSelectedSubject.eraseToAnyPublisher()
        )

        let output = viewModel.convert(input: input)

        output.connectionStateOut
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.stateLabel.text = "State: \(Self.stringValue(for: state))"
                let isConnected: Bool
                if case .connected = state {
                    isConnected = true
                } else {
                    isConnected = false
                }
                self?.openCaptionsButton.isEnabled = isConnected
                self?.endCaptionsButton.isEnabled = isConnected
                self?.devicesTitleLabel.isHidden = isConnected
                self?.devicesTableView.isHidden = isConnected
            }
            .store(in: &cancellables)

        output.linkedTargetOut
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.linkedTargetLabel.text = value
            }
            .store(in: &cancellables)

        output.transcriptOut
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.transcriptTextView.text = text.isEmpty ? "Waiting for speech..." : text
            }
            .store(in: &cancellables)

        output.discoveredDevicesOut
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.discoveredDevices = devices
                self?.devicesTableView.reloadData()
            }
            .store(in: &cancellables)

        output.logsOut
            .receive(on: DispatchQueue.main)
            .scan([String]()) { current, next in
                Array((current + [next]).suffix(300))
            }
            .sink { [weak self] lines in
                let text = lines.joined(separator: "\n")
                self?.logsTextView.text = text
                guard !text.isEmpty else { return }
                let range = NSRange(location: max(text.count - 1, 0), length: 1)
                self?.logsTextView.scrollRangeToVisible(range)
            }
            .store(in: &cancellables)

        output.connectTapOut.sink { _ in }.store(in: &cancellables)
        output.disconnectTapOut.sink { _ in }.store(in: &cancellables)
        output.openCaptionsTapOut.sink { _ in }.store(in: &cancellables)
        output.endCaptionsTapOut.sink { _ in }.store(in: &cancellables)
        output.unlinkTapOut.sink { _ in }.store(in: &cancellables)
        output.deviceSelectedOut.sink { _ in }.store(in: &cancellables)
    }

    @objc private func connectTapped() {
        connectTapSubject.send(())
    }

    @objc private func disconnectTapped() {
        disconnectTapSubject.send(())
    }

    @objc private func openCaptionsTapped() {
        openCaptionsTapSubject.send(())
    }

    @objc private func endCaptionsTapped() {
        endCaptionsTapSubject.send(())
    }

    @objc private func unlinkTapped() {
        unlinkTapSubject.send(())
    }

    private func buildLayout() {
        let buttonStack = UIStackView(arrangedSubviews: [connectButton, disconnectButton, unlinkButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.distribution = .fillEqually

        let logsTitle = titleLabel("BLE Logs")

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)

        contentStack.addArrangedSubview(stateLabel)
        contentStack.addArrangedSubview(linkedTargetLabel)
        contentStack.addArrangedSubview(buttonStack)
        let captionsButtonsStack = UIStackView(arrangedSubviews: [openCaptionsButton, endCaptionsButton])
        captionsButtonsStack.translatesAutoresizingMaskIntoConstraints = false
        captionsButtonsStack.axis = .horizontal
        captionsButtonsStack.spacing = 8
        captionsButtonsStack.distribution = .fillEqually

        contentStack.addArrangedSubview(captionsButtonsStack)
        contentStack.addArrangedSubview(devicesTitleLabel)
        contentStack.addArrangedSubview(devicesTableView)
        contentStack.addArrangedSubview(transcriptTitleLabel)
        contentStack.addArrangedSubview(transcriptTextView)
        contentStack.addArrangedSubview(logsTitle)
        contentStack.addArrangedSubview(logsTextView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            devicesTableView.heightAnchor.constraint(equalToConstant: 240),
            transcriptTextView.heightAnchor.constraint(equalToConstant: 150),
            logsTextView.heightAnchor.constraint(equalToConstant: 560)
        ])
    }

    private func titleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.text = text
        return label
    }

    private static func stringValue(for state: HallidayConnectionState) -> String {
        switch state {
        case .disconnected: return "disconnected"
        case .scanning: return "scanning"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .error(let message): return "error: \(message)"
        }
    }
}

extension HomeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(discoveredDevices.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellId = "DeviceCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId) ?? UITableViewCell(style: .subtitle, reuseIdentifier: cellId)

        guard !discoveredDevices.isEmpty else {
            cell.textLabel?.text = "No devices found yet"
            cell.detailTextLabel?.text = "Tap Scan / Connect"
            cell.selectionStyle = .none
            cell.accessoryType = .none
            return cell
        }

        let device = discoveredDevices[indexPath.row]
        cell.textLabel?.text = device.name
        cell.detailTextLabel?.text = "\(device.id.uuidString) | RSSI: \(device.rssi)"
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        return cell
    }
}

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !discoveredDevices.isEmpty else { return }
        deviceSelectedSubject.send(discoveredDevices[indexPath.row])
    }
}
