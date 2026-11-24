import SwiftUI
import UIKit

/// Pages that turn with a page curl, one at a time, like a real book. Each
/// page's picture is loaded when the page comes up, so long books stay light.
struct CurlPager: UIViewControllerRepresentable {
    let count: Int
    @Binding var index: Int
    /// Bumped to make visible pages load their picture again (after editing).
    var reloadToken = 0
    let image: (Int) async -> UIImage?
    var onTap: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal,
                                         options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue])
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        pager.view.backgroundColor = .clear
        pager.setViewControllers([context.coordinator.page(index)], direction: .forward, animated: false)
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let shown = pager.viewControllers?.first as? CurlPageController else { return }
        if coordinator.token != reloadToken {
            coordinator.token = reloadToken
            pager.setViewControllers([coordinator.page(shown.index)], direction: .forward, animated: false)
            return
        }
        // An arrow or thumbnail moved the index: turn to that page.
        guard shown.index != index, (0..<count).contains(index) else { return }
        pager.setViewControllers([coordinator.page(index)],
                                 direction: index > shown.index ? .forward : .reverse, animated: true)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: CurlPager
        var token: Int
        init(_ parent: CurlPager) {
            self.parent = parent
            self.token = parent.reloadToken
        }

        func page(_ i: Int) -> CurlPageController {
            let loader = parent.image
            let tap = parent.onTap
            return CurlPageController(index: i, load: { await loader(i) }, onTap: tap.map { t in { t(i) } })
        }

        func pageViewController(_ pvc: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard let i = (vc as? CurlPageController)?.index, i > 0 else { return nil }
            return page(i - 1)
        }

        func pageViewController(_ pvc: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
            guard let i = (vc as? CurlPageController)?.index, i + 1 < parent.count else { return nil }
            return page(i + 1)
        }

        func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let i = (pvc.viewControllers?.first as? CurlPageController)?.index else { return }
            parent.index = i
            SoundFX.shared.play(.tap)
        }
    }
}

/// One sheet on screen: white paper the shape of its picture, with a shadow.
final class CurlPageController: UIViewController {
    let index: Int
    private let load: () async -> UIImage?
    private let onTap: (() -> Void)?
    private let paper = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .large)

    init(index: Int, load: @escaping () async -> UIImage?, onTap: (() -> Void)?) {
        self.index = index
        self.load = load
        self.onTap = onTap
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        paper.contentMode = .scaleAspectFit
        paper.backgroundColor = .white
        paper.layer.shadowColor = UIColor.black.cgColor
        paper.layer.shadowOpacity = 0.22
        paper.layer.shadowRadius = 10
        paper.layer.shadowOffset = CGSize(width: 0, height: 4)
        paper.isUserInteractionEnabled = true
        if onTap != nil {
            paper.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        }
        view.addSubview(paper)
        spinner.startAnimating()
        view.addSubview(spinner)
        Task { [weak self] in
            guard let self else { return }
            let image = await self.load()
            self.paper.image = image
            self.spinner.stopAnimating()
            self.view.setNeedsLayout()
        }
    }

    @objc private func tapped() { onTap?() }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Paper the shape of the picture, Letter until it arrives.
        let ratio = paper.image.map { $0.size.width / $0.size.height } ?? 612 / 792
        let bounds = view.bounds.insetBy(dx: 16, dy: 10)
        var size = CGSize(width: bounds.width, height: bounds.width / ratio)
        if size.height > bounds.height { size = CGSize(width: bounds.height * ratio, height: bounds.height) }
        paper.frame = CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                             width: size.width, height: size.height)
        paper.layer.shadowPath = UIBezierPath(rect: paper.bounds).cgPath
        spinner.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }
}
