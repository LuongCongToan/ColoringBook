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
    var sounds = true

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal,
                                         options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue])
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        pager.view.backgroundColor = .clear
        pager.setViewControllers([context.coordinator.page(index)], direction: .forward, animated: false)
        // UIKit's curl crashes ("view controllers provided (0) doesn't match
        // the number required (1)") when a swipe or edge tap starts toward a
        // page that does not exist, or during another turn (user crash,
        // 2026-11-26). The coordinator stops those gestures from starting.
        context.coordinator.pager = pager
        for gesture in pager.gestureRecognizers { gesture.delegate = context.coordinator }
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let shown = pager.viewControllers?.first as? CurlPageController else { return }
        if coordinator.token != reloadToken {
            coordinator.token = reloadToken
            // The page may have moved (a photo page added before it).
            let target = (0..<count).contains(index) ? index : shown.index
            pager.setViewControllers([coordinator.page(target)], direction: .forward, animated: false)
            return
        }
        // An arrow or thumbnail moved the index: turn to that page.
        guard shown.index != index, (0..<count).contains(index) else { return }
        coordinator.turning = true
        pager.setViewControllers([coordinator.page(index)],
                                 direction: index > shown.index ? .forward : .reverse, animated: true) { _ in
            coordinator.turning = false
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate,
                             UIGestureRecognizerDelegate {
        var parent: CurlPager
        var token: Int
        weak var pager: UIPageViewController?
        /// A turn is under way; no new one may start until it ends.
        var turning = false
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

        func pageViewController(_ pvc: UIPageViewController, willTransitionTo pending: [UIViewController]) {
            turning = true
        }

        func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            turning = false
            guard completed, let i = (pvc.viewControllers?.first as? CurlPageController)?.index else { return }
            parent.index = i
            if parent.sounds { SoundFX.shared.play(.tap) }
        }

        /// Lets the pager's own swipe and edge tap start only toward a page
        /// that exists, and never during a turn.
        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            guard !turning, let pager,
                  let i = (pager.viewControllers?.first as? CurlPageController)?.index else { return false }
            let forward: Bool
            if let pan = gesture as? UIPanGestureRecognizer {
                let v = pan.velocity(in: pager.view)
                guard v.x != 0 else { return false }
                forward = v.x < 0
            } else {
                forward = gesture.location(in: pager.view).x > pager.view.bounds.midX
            }
            return forward ? i + 1 < parent.count : i > 0
        }
    }
}

/// One sheet on screen. The pager is sized to exactly one Letter-shaped
/// sheet, so this view *is* the paper: when it curls there is no empty area
/// around it to show up grey. The picture sits inside with a white margin;
/// full-page pictures (cover, name page) are Letter-shaped and fill it.
final class CurlPageController: UIViewController {
    static let sheetRatio: CGFloat = 612 / 792
    /// Margin around a picture, as a share of the sheet's width. Small:
    /// pages carry their own white border around the frame already.
    static let margin: CGFloat = 0.03

    let index: Int
    private let load: () async -> UIImage?
    private let onTap: (() -> Void)?
    private let picture = UIImageView()
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
        view.backgroundColor = .white
        if onTap != nil {
            view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        }
        picture.contentMode = .scaleAspectFit
        view.addSubview(picture)
        spinner.startAnimating()
        view.addSubview(spinner)
        Task { [weak self] in
            guard let self else { return }
            let image = await self.load()
            self.picture.image = image
            self.spinner.stopAnimating()
            self.view.setNeedsLayout()
        }
    }

    @objc private func tapped() { onTap?() }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let fullPage = picture.image.map { abs($0.size.width / $0.size.height - Self.sheetRatio) < 0.02 } ?? false
        let inset = fullPage ? 0 : view.bounds.width * Self.margin
        picture.frame = view.bounds.insetBy(dx: inset, dy: inset)
        spinner.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }
}
