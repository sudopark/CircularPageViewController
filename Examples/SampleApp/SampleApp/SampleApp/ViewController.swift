//
//  ViewController.swift
//  SampleApp
//
//  Created by sudo.park on 5/1/25.
//

import UIKit
import CircularPageViewController

class ViewController: UIViewController {
    
    private let label = UILabel()
    private let containerView = UIView()
    private let pageViewController = CircularPageViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = .white
        self.setupViews()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupChilds()
        }
    }
    
    private func setupChilds() {
        
        let childs = (0..<10).map { int in
            return ChildViewController(index: int)
        }
        self.pageViewController.updateChilds(childs, withSelect: 1)
    }
    
    private func setupViews() {
        self.view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        ])
        label.textColor = .black
        
        self.view.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        self.addChild(self.pageViewController)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.containerView.addSubview(pageViewController.view)
        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
}

final class ChildViewController: UIViewController {
    
    private let label = UILabel()
    private let index: Int
    
    init(index: Int) {
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        print("     \(#function) - \(index)")
        
        self.view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
        label.textColor = .black
        label.text = "\(index)"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("     + \(#function) - \(index)")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("     ++ \(#function) - \(index)")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("     - \(#function) - \(index)")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("     -- \(#function) - \(index)")
    }
}

