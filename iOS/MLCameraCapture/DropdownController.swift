//
//  DropdownController.swift
//  MLCameraCapture
//
//  Created by Wilhelm Thieme on 10/09/2019.
//  Copyright © 2019 Sogeti Nederland B.V. All rights reserved.
//

import UIKit

class DropdownController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    
    private let kReuseIdentifier = "reuseID"
    
    private let background = UIButton()
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    private var anchor = CGPoint.zero
    private var anchorLocation = AnchorLocation.topLeft
    
    private var cells: [(String, Bool, (() -> Void)?)] = []
    
    var dismissesOnSelection = true
    var maxVisibleCells = 5 { didSet { setIsScrollable() } }
    
    private var origin: CGPoint {
        switch anchorLocation {
        case .topLeft:
            return anchor
        case .topRight:
            return CGPoint(x: anchor.x - width, y: anchor.y)
        case .bottomLeft:
            return CGPoint(x: anchor.x, y: anchor.y - height)
        case .bottomRight:
            return CGPoint(x: anchor.x - width, y: anchor.y - height)
        }
    }
    
    private var cellHeight = CGFloat(44)
    
    enum AnchorLocation {
        case topLeft, topRight, bottomLeft, bottomRight
        var isTop: Bool { return self == .topLeft || self == .topRight }
        var isLeft: Bool { return self == .topLeft || self == .bottomLeft }
    }
    
    convenience init(anchor: CGPoint, anchorLocation: AnchorLocation) {
        self.init()
        self.anchor = anchor
        self.anchorLocation = anchorLocation
        modalTransitionStyle = .crossDissolve
        modalPresentationStyle = .overCurrentContext
    }
    
    func addRow(title: String, checked: Bool = false, action: (() -> Void)? = nil) {
        cells.append((title, checked, action))
        setIsScrollable()
    }
    
    private func setIsScrollable() {
        tableView.isScrollEnabled = (maxVisibleCells != 0 && cells.count > maxVisibleCells)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        background.addTarget(self, action: #selector(backgroundPressed), for: .touchUpInside)
        background.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(background)
        background.leadingAnchor.constraint(equalTo: view.leadingAnchor).activated()
        background.trailingAnchor.constraint(equalTo: view.trailingAnchor).activated()
        background.topAnchor.constraint(equalTo: view.topAnchor).activated()
        background.bottomAnchor.constraint(equalTo: view.bottomAnchor).activated()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: kReuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.layer.shadowRadius = 2
        tableView.layer.shadowColor = UIColor.black.cgColor
        tableView.layer.shadowOffset = .zero
        tableView.layer.shadowOpacity = 0.1
        tableView.layer.masksToBounds = true
        tableView.layer.cornerRadius = 2
        tableView.backgroundColor = UIColor(named: "background")
        tableView.separatorStyle = .none
        tableView.showsHorizontalScrollIndicator = false
        view.addSubview(tableView)
        tableView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: .padding).activated()
        tableView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -.padding).activated()
        tableView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: .padding).activated()
        tableView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -.padding).activated()
        tableView.heightAnchor.constraint(equalToConstant: height).activated()
        tableView.widthAnchor.constraint(equalToConstant: width).activated()
        
        let x = anchorLocation.isLeft ? anchor.x : anchor.x - width
        let y = anchorLocation.isTop ? anchor.y : anchor.y - height
        
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: x).activated(.defaultHigh)
        tableView.topAnchor.constraint(equalTo: view.topAnchor, constant: y).activated(.defaultHigh)
        
    }
    
    private var scrollbarTimer: Timer?
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.layer.shadowPath = CGPath(rect: self.tableView.frame, transform: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard tableView.isScrollEnabled else { return }
        scrollbarTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] time in
            guard let self = self else { time.invalidate(); return }
            UIView.animate(withDuration: 0.001) { self.tableView.flashScrollIndicators() }
        })
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        scrollbarTimer?.invalidate()
    }
    
    private var height: CGFloat {
        if maxVisibleCells == 0 { return cellHeight * CGFloat(cells.count) }
        let h = min(cellHeight * CGFloat(cells.count), cellHeight * CGFloat(maxVisibleCells))
        return min(h, maxHeight)
    }
    
    private var maxHeight: CGFloat { return view.frame.width - .padding * 3 }
    private var maxWidth: CGFloat { return view.frame.width - .padding * 3 }
    
    var minWidth = CGFloat(200)
    private var width: CGFloat {
        let str = cells.max(by: { return $0.0.count < $1.0.count })?.0
        let label = UILabel()
        label.numberOfLines = 1
        label.text = str
        label.adjustsFontSizeToFitWidth = false
        label.sizeToFit()
        let minW = max(minWidth, label.bounds.width + .padding * 4)
        return min(minW, maxWidth)
    }
    
    @objc private func backgroundPressed() { dismiss(animated: true, completion: nil) }
    
    //MARK: TableView Delegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return cellHeight
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kReuseIdentifier)!
        
        cell.textLabel?.text = cells[indexPath.row].0
        cell.textLabel?.textColor = UIColor(named: "text")
        cell.backgroundColor = UIColor(named: "background")
        cell.tintColor = UIColor(named: "tint")
        cell.accessoryType = cells[indexPath.row].1 ? .checkmark : .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        cells[indexPath.row].2?()
        if dismissesOnSelection { dismiss(animated: true, completion: nil); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
            tableView.cellForRow(at: indexPath)?.setSelected(false, animated: true)
        })
    }
}

