// The Swift Programming Language
// https://docs.swift.org/swift-book

#if canImport(UIKit)
import UIKit


public protocol CircularPageViewControllerDelegate: AnyObject {
    
    func circularPageViewController(
        _ pageViewController: CircularPageViewController,
        willTransitionTo viewController: UIViewController,
        at index: Int
    )
    
    func circularPageViewController(
        _ pageViewController: CircularPageViewController,
        didFinishTransitionTo viewController: UIViewController,
        at index: Int
    )
}

open class CircularPageViewController: UIViewController {
    
    public weak var delegate: (any CircularPageViewControllerDelegate)?
    private let scrollView = UIScrollView()
    
    private var viewControllers: [UIViewController] = []
    private var currentIndex: Int?
    private var visibleViewControllers: [UIViewController] = [] {
        didSet {
            print("update visible: \(visibleViewControllers.count)")
        }
    }
    private var currentViewController: UIViewController? {
        return self.currentIndex.flatMap { self.viewControllers[safe: $0] }
    }
    private var currentVisibleIndex: Int? {
        return self.currentViewController
            .flatMap { self.visibleViewControllers.firstIndex(of: $0) }
    }
    
    private var lastScrollViewSize: CGSize?
    
    private var isDragging: Bool = false
    private var pendingAppearPageIndex: Int?
    
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
    
    open func updatePages(_ childs: [UIViewController], withSelect index: Int = 0) {
        self.clear()
        self.viewControllers = childs
        self.currentIndex = index
        self.prepareVisiblePages(around: index)
        self.updatePages(withTransitionCurrent: true)
    }
    
    open func selecPage(at index: Int) {
        guard self.currentIndex != index, let newCurrent = self.viewControllers[safe: index] else { return }
        
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
        self.isDragging = true
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        guard self.isDragging,
              let currentIndex = self.currentIndex,
              let newCurrentIndex = self.findWillScrollFocusIndex(currentIndex),
            self.pendingAppearPageIndex != newCurrentIndex
        else { return }
        
        print("pending: \(pendingAppearPageIndex), new: \(newCurrentIndex), offset: \(self.scrollView.contentOffset.x), width: \(self.scrollView.bounds.width)")
        
        func handleWillShow(_ pair: (Int, UIViewController)?) {
            guard let (index, next) = pair else { return }
            
            // cancel previous pending vc appearing
            let pending = self.pendingAppearPageIndex.flatMap { self.viewControllers[safe: $0] }
            pending?.beginAppearanceTransition(false, animated: false)
            
            // notify will move to next or previous
            self.delegate?.circularPageViewController(self, willTransitionTo: next, at: index)
            self.currentViewController?.beginAppearanceTransition(false, animated: false)
            self.pendingAppearPageIndex = index
        }
        
        if self.viewControllers.isMoveToNext(currentIndex, newCurrentIndex) {
            handleWillShow(self.prepareWillShowNext())
        } else {
            handleWillShow(self.prepareeWillShowPrevious())
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        defer { self.isDragging = false }
        guard !decelerate else { return }
        self.handleScrollEnd()
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.handleScrollEnd()
        self.isDragging = false
    }
    
    private func handleScrollEnd() {
        defer { self.pendingAppearPageIndex = nil }
        guard let previousCurrentIndex = self.currentIndex,
              let currentPageIndex = self.findCurrentScrollFocusIndex(),
              let current = self.viewControllers[safe: currentPageIndex]
        else { return }
        
        print("did, prev: \(previousCurrentIndex) -> \(currentPageIndex)")
        
        guard previousCurrentIndex != currentPageIndex
        else {
            self.currentViewController?.beginAppearanceTransition(true, animated: false)
            self.currentViewController?.endAppearanceTransition()
            
            let pending = self.pendingAppearPageIndex.flatMap { self.viewControllers[safe: $0] }
            pending?.endAppearanceTransition()
            return
        }

        let isMoveToNext = self.viewControllers.isMoveToNext(previousCurrentIndex, currentPageIndex)
        
        if isMoveToNext, let next = self.viewControllers.next(at: currentPageIndex) {
            let previousFirst = self.visibleViewControllers.removeFirst()
            self.removePage(previousFirst, withEndTransition: true)
            self.visibleViewControllers.append(next)
        } else if let previous = self.viewControllers.previous(at: currentPageIndex) {
            let previousLast = self.visibleViewControllers.removeLast()
            self.removePage(previousLast, withEndTransition: true)
            self.visibleViewControllers.insert(previous, at: 0)
        }
        self.currentIndex = currentPageIndex
        self.viewControllers[safe: currentPageIndex]?.endAppearanceTransition()
        self.viewControllers[safe: previousCurrentIndex]?.endAppearanceTransition()
        
        self.updatePages()
        self.delegate?.circularPageViewController(self, didFinishTransitionTo: current, at: currentPageIndex)
    }
    
    private func prepareWillShowNext() -> (Int, UIViewController)? {
        guard let currentIndex = self.currentIndex,
              let nextIndex = self.viewControllers.nextIndex(at: currentIndex)
        else { return nil }
        let next = self.viewControllers[nextIndex]
        
        guard next.parent == nil
        else {
            next.beginAppearanceTransition(true, animated: false)
            return (nextIndex, next)
        }
        
        let size = self.scrollView.bounds.size
        let start = self.scrollView.contentSize.width
        self.scrollView.contentSize.width += size.width
        
        let frame: CGRect = .init(origin: .init(x: start, y: 0), size: size)
        self.addPage(next, with: frame, withBeginTransition: true, withEndTransition: true)
        self.visibleViewControllers.append(next)
        return (nextIndex, next)
    }
    
    private func prepareeWillShowPrevious() -> (Int, UIViewController)? {
        guard let currentIndex = self.currentIndex,
              let previousIndex = self.viewControllers.previousIndex(at: currentIndex)
        else { return nil }
        
        let previous = self.viewControllers[previousIndex]
        
        guard previous.parent == nil
        else {
            previous.beginAppearanceTransition(true, animated: false)
            return (previousIndex, previous)
        }
        
        let size = self.scrollView.bounds.size
        let frame: CGRect = .init(origin: .init(x: -size.width, y: 0), size: size)
        self.addPage(previous, with: frame, withBeginTransition: true, withEndTransition: true)
        self.visibleViewControllers.insert(previous, at: 0)
        return (previousIndex, previous)
    }
    
    private func findWillScrollFocusIndex(_ currentIndex: Int) -> Int? {
        let width = self.scrollView.bounds.width
        let offset = self.scrollView.contentOffset.x + self.scrollView.contentInset.left
        let visibleIndex = Int(round(offset / width))
        if offset < 0 {
            return self.viewControllers.previousIndex(at: currentIndex)
        } else if offset > self.scrollView.contentSize.width {
            return self.viewControllers.nextIndex(at: currentIndex)
        } else {
            return self.visibleViewControllers[safe: visibleIndex]
                .flatMap { self.viewControllers.firstIndex(of: $0) }
        }
    }
    
    private func findCurrentScrollFocusIndex() -> Int? {
        let width = self.scrollView.bounds.width
        let offset = self.scrollView.contentOffset.x
        let totalScrollablePageWidth = self.scrollView.contentInset.left + self.scrollView.contentSize.width
        let totalScrollablePageCount = Int(round(totalScrollablePageWidth / width)) + 1
        let visibleIndex = if visibleViewControllers.count < totalScrollablePageCount {
            max(0, Int(round(offset / width)) - 1)
        } else {
            max(0, Int(round(offset / width)))
        }
        return self.visibleViewControllers[safe: visibleIndex]
            .flatMap { self.viewControllers.firstIndex(of: $0) }
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
    
    func nextIndex(at index: Int) -> Int? {
        guard !self.isEmpty else { return nil }
        return (index + 1) % self.count
    }
    
    func next(at index: Int) -> Element? {
        return self.nextIndex(at: index).map { self[$0] }
    }
    
    func previousIndex(at index: Int) -> Int? {
        guard !self.isEmpty else { return nil }
        return (self.count + index - 1) % self.count
    }
    
    func previous(at index: Int) -> Element? {
        return self.previousIndex(at: index).map { self[$0] }
    }
    
    func isMoveToNext(_ old: Int, _ new: Int) -> Bool {
        let isMoveToFirstFromLast = old == self.count-1 && new == 0
        let isMoveToLastFromFirst = old == 0 && new == self.count-1
        let isMoveToNext = (old < new && !isMoveToLastFromFirst) || isMoveToFirstFromLast
        return isMoveToNext
    }
}

#endif
