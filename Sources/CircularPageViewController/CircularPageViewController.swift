// The Swift Programming Language
// https://docs.swift.org/swift-book

#if canImport(UIKit)
import UIKit


open class CircularPageViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    
    private var viewControllers: [UIViewController] = []
    private var currentIndex: Int? {
        didSet {
            print("curent index: \(currentIndex)")
        }
    }
    private var visibleViewControllers: [UIViewController] = []
    private var currentViewController: UIViewController? {
        return self.currentIndex.flatMap { self.viewControllers[safe: $0] }
    }
    private var currentVisibleIndex: Int? {
        return self.currentViewController
            .flatMap { self.visibleViewControllers.firstIndex(of: $0) }
    }
    
    private var lastScrollViewSize: CGSize?
    
    private var scrollStartOffsetX: CGFloat?
    private var pendingAppearChild: UIViewController?
    
    open override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }

    open override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViews()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.currentViewController?.beginAppearanceTransition(true, animated: animated)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.currentViewController?.endAppearanceTransition()
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.currentViewController?.beginAppearanceTransition(false, animated: animated)
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.currentViewController?.endAppearanceTransition()
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.updatePagesIfNeed()
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.updatePagesIfNeed()
        }
    }
    
    open func updateChilds(_ childs: [UIViewController], withSelect index: Int = 0) {
        self.clear()
        self.viewControllers = childs
        self.currentIndex = index
        self.prepareVisiblePages(around: index)
        self.updatePages(withTransitionCurrent: true)
    }
    
    open func selecChild(at index: Int) {
        guard self.currentIndex != index else { return }
        
        self.clear()
        self.currentIndex = index
        self.prepareVisiblePages(around: index)
        self.updatePages(withTransitionCurrent: true)
    }
}


// MARK: - update pages

extension CircularPageViewController {
    
    private func clear() {
        self.visibleViewControllers.forEach {
            self.removePage($0, withBeginTransition: true, withEndTransition: true)
        }
        self.visibleViewControllers.removeAll()
    }
    
    private func prepareVisiblePages(around currentIndex: Int) {
        guard let current = self.viewControllers[safe: currentIndex] else { return }
        self.visibleViewControllers = [current]
    }
    
    private func updatePagesIfNeed() {
        let size = self.scrollView.bounds.size
        guard !size.equalTo(.zero), size != self.lastScrollViewSize else { return }
        self.updatePages()
    }

    private func updatePages(withTransitionCurrent: Bool = false) {
        let size = self.scrollView.bounds.size
        self.scrollView.contentSize =  CGSize(
            width: CGFloat(self.visibleViewControllers.count) * size.width, height: size.height
        )
        self.scrollView.contentInset = .init(top: 0, left: size.width, bottom: 0, right: 0)
        self.visibleViewControllers.enumerated().forEach { visibleIndex, viewController in
            let offsetX = CGFloat(visibleIndex) * size.width
            let frame: CGRect = .init(origin: .init(x: offsetX, y: 0), size: size)
            if viewController.parent == nil {
                let index = self.viewControllers.firstIndex(of: viewController)
                let needTransition = index != nil && index == self.currentIndex
                self.addPage(viewController, with: frame, withBeginTransition: needTransition, withEndTransition: needTransition)
            } else {
                viewController.view.frame = frame
            }
        }
        self.focusCurrent()
        self.lastScrollViewSize = self.scrollView.bounds.size
    }
    
    private func focusCurrent() {
        guard let currentVisibleIndex = self.currentVisibleIndex else { return }
        let offset = CGFloat(currentVisibleIndex) * self.scrollView.bounds.width
        self.scrollView.setContentOffset(.init(x: offset, y: 0), animated: false)
    }
}


// MARK: - handle scrollView delegate

extension CircularPageViewController: UIScrollViewDelegate {
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.scrollStartOffsetX = scrollView.contentOffset.x
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let start = self.scrollStartOffsetX else { return }
        self.scrollStartOffsetX = nil
        
        if scrollView.contentOffset.x > start, let next = self.prepareWillShowNext() {
            self.currentViewController?.beginAppearanceTransition(false, animated: false)
            self.pendingAppearChild = next
        } else if let previous = self.preapreWillShowPrevious() {
            self.currentViewController?.beginAppearanceTransition(false, animated: false)
            self.pendingAppearChild = previous
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        guard let previousCurrentIndex = self.currentIndex,
              let currentPageIndex = self.findCurrentScrollFocusIndex()
        else { return }
        
        guard previousCurrentIndex != currentPageIndex
        else {
            self.currentViewController?.beginAppearanceTransition(true, animated: false)
            self.currentViewController?.endAppearanceTransition()
            
            self.pendingAppearChild?.beginAppearanceTransition(false, animated: false)
            self.pendingAppearChild?.endAppearanceTransition()
            return
        }

        let isMoveToNext = self.isMoveToNext(previousCurrentIndex, currentPageIndex)
        
        if isMoveToNext, let next = self.nextViewController(at: currentPageIndex) {
            let previousFirst = self.visibleViewControllers.removeFirst()
            self.removePage(previousFirst, withEndTransition: true)
            self.visibleViewControllers.append(next)
        } else if let previous = self.previousViewController(at: currentPageIndex) {
            let previousLast = self.visibleViewControllers.removeLast()
            self.removePage(previousLast, withEndTransition: true)
            self.visibleViewControllers.insert(previous, at: 0)
        }
        self.currentIndex = currentPageIndex
        self.viewControllers[safe: currentPageIndex]?.endAppearanceTransition()
        self.viewControllers[safe: previousCurrentIndex]?.endAppearanceTransition()
        
        self.updatePages()
    }
    
    private func prepareWillShowNext() -> UIViewController? {
        guard let next = self.currentIndex.flatMap ({ self.nextViewController(at: $0) })
        else { return nil }
        
        guard next.parent == nil
        else {
            next.beginAppearanceTransition(true, animated: false)
            return next
        }
        
        let size = self.scrollView.bounds.size
        let start = self.scrollView.contentSize.width
        self.scrollView.contentSize.width += size.width
        
        let frame: CGRect = .init(origin: .init(x: start, y: 0), size: size)
        self.addPage(next, with: frame, withBeginTransition: true, withEndTransition: true)
        self.visibleViewControllers.append(next)
        return next
    }
    
    private func preapreWillShowPrevious() -> UIViewController? {
        guard let previous = self.currentIndex.flatMap({ self.previousViewController(at: $0) })
        else { return nil }
        
        guard previous.parent == nil
        else {
            previous.beginAppearanceTransition(true, animated: false)
            return previous
        }
        
        let size = self.scrollView.bounds.size
        let frame: CGRect = .init(origin: .init(x: -size.width, y: 0), size: size)
        self.addPage(previous, with: frame, withBeginTransition: true, withEndTransition: true)
        self.visibleViewControllers.insert(previous, at: 0)
        return previous
    }
    
    private func findCurrentScrollFocusIndex() -> Int? {
        let width = self.scrollView.bounds.width
        let index = max(0, Int(round(self.scrollView.contentOffset.x / width)))
        return self.visibleViewControllers[safe: index]
            .flatMap { self.viewControllers.firstIndex(of: $0) }
    }
    
    private func isMoveToNext(_ old: Int, _ new: Int) -> Bool {
        let isMoveToFirstFromLast = old == self.viewControllers.count-1 && new == 0
        let isMoveToLastFromFirst = old == 0 && new == self.viewControllers.count-1
        let isMoveToNext = (old < new && !isMoveToLastFromFirst) || isMoveToFirstFromLast
        return isMoveToNext
    }
}

extension CircularPageViewController {
    
    private func addPage(
        _ viewController: UIViewController,
        with frame: CGRect,
        withBeginTransition: Bool = false,
        withEndTransition: Bool = false
    ) {
        if withBeginTransition {
            viewController.beginAppearanceTransition(true, animated: false)
        }
        addChild(viewController)
        viewController.view.frame = frame
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.scrollView.addSubview(viewController.view)
        viewController.didMove(toParent: self)
        if withEndTransition {
            viewController.endAppearanceTransition()
        }
    }
    
    private func removePage(
        _ viewController: UIViewController,
        withBeginTransition: Bool = false,
        withEndTransition: Bool = false
    ) {
        if withBeginTransition {
            viewController.beginAppearanceTransition(false, animated: false)
        }
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
        if withEndTransition {
            viewController.endAppearanceTransition()
        }
    }
    
    private func nextViewController(at index: Int) -> UIViewController? {
        guard !self.viewControllers.isEmpty else { return nil }
        let nextIndex = (index + 1) % self.viewControllers.count
        return self.viewControllers[nextIndex]
    }
    
    private func previousViewController(at index: Int) -> UIViewController? {
        guard !self.viewControllers.isEmpty else { return nil }
        let previousIndex = (self.viewControllers.count + index - 1) % self.viewControllers.count
        return self.viewControllers[previousIndex]
    }
    
    private func setupViews() {
        
        self.view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.scrollsToTop = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isPagingEnabled = true
        scrollView.delegate = self
    }
}

private extension Array {
    
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#endif
