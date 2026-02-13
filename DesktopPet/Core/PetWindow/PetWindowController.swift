import AppKit
import SwiftUI
import Combine

class PetWindowController: NSWindowController {
    private var viewModel: PetViewModel
    private var cancellables = Set<AnyCancellable>()

    init() {
        let window = PetWindow()
        viewModel = PetViewModel()
        let hostingView = NSHostingView(rootView: PetView(viewModel: viewModel))
        window.contentView = hostingView

        super.init(window: window)

        // 监听图片选择通知
        NotificationCenter.default.publisher(for: .petImageSelected)
            .compactMap { $0.object as? URL }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.viewModel.loadPetImage(from: url)
            }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        showWindow(nil)
    }
}
