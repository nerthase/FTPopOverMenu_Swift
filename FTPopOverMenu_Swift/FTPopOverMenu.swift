//
//  FTPopOverMenu.swift
//  FTPopOverMenu
//
//  Created by liufengting on 16/11/2016.
//  Copyright © 2016 LiuFengting (https://github.com/liufengting) . All rights reserved.
//

import UIKit

extension FTPopOverMenu {
    
    public static func showForSender(sender : UIView, with menuArray: [String], done: @escaping (NSInteger) -> Void, cancel:@escaping () -> Void) {
        self.sharedMenu.showForSender(sender: sender, or: nil, with: menuArray, menuImageArray: [], done: done, cancel: cancel)
    }
    public static func showForSender(sender : UIView, with menuArray: [String], menuImageArray: [AnyObject], done: @escaping (NSInteger) -> Void, cancel:@escaping () -> Void) {
        self.sharedMenu.showForSender(sender: sender, or: nil, with: menuArray, menuImageArray: menuImageArray, done: done, cancel: cancel)
    }
    
    public static func showForEvent(event : UIEvent, with menuArray: [String], done: @escaping (NSInteger) -> Void, cancel:@escaping () -> Void) {
        self.sharedMenu.showForSender(sender: event.allTouches?.first?.view!, or: nil, with: menuArray, menuImageArray: [], done: done, cancel: cancel)
    }
    public static func showForEvent(event : UIEvent, with menuArray: [String], menuImageArray: [AnyObject], done: @escaping (NSInteger) -> Void, cancel:@escaping () -> Void) {
        self.sharedMenu.showForSender(sender: event.allTouches?.first?.view!, or: nil, with: menuArray, menuImageArray: menuImageArray, done: done, cancel: cancel)
    }
    
    public static func showFromSenderFrame(senderFrame : CGRect, with menuArray: [String], done: @escaping (NSInteger) -> Void, cancel:@escaping () -> Void) {
        self.sharedMenu.showForSender(sender: nil, or: senderFrame, with: menuArray, menuImageArray: [], done: done, cancel: cancel)
    }
    public static func showFromSenderFrame(senderFrame : CGRect, with menuArray: [String], menuImageArray: [AnyObject], done: @escaping (NSInteger) -> Void, cancel:@escaping () -> Void) {
        self.sharedMenu.showForSender(sender: nil, or: senderFrame, with: menuArray, menuImageArray: menuImageArray, done: done, cancel: cancel)
    }
    
    public static func dismiss() {
        self.sharedMenu.dismiss()
    }
}

fileprivate enum FTPopOverMenuArrowDirection {
    case up
    case down
}

public class FTPopOverMenu : NSObject {
    
    var sender : UIView?
    var senderFrame : CGRect?
    var menuNameArray : [String]!
    var menuImageArray : [AnyObject]!
    var done : ((_ selectedIndex : NSInteger) -> Void)!
    var cancel : (() -> Void)!
    
    fileprivate static var sharedMenu : FTPopOverMenu {
        struct Static {
            static let instance : FTPopOverMenu = FTPopOverMenu()
        }
        return Static.instance
    }
    
    fileprivate lazy var configuration : FTConfiguration = {
        return FTConfiguration.shared
    }()
    
    fileprivate lazy var backgroundView : UIView = {
        let view = UIView(frame: UIScreen.main.bounds)
        if self.configuration.globalShadow {
            view.backgroundColor = UIColor.black.withAlphaComponent(self.configuration.shadowAlpha)
        }
        view.addGestureRecognizer(self.tapGesture)
        return view
    }()
    
    fileprivate lazy var popOverMenu : FTPopOverMenuView = {
        let menu = FTPopOverMenuView(frame: CGRect.zero)
        menu.alpha = 0
        self.backgroundView.addSubview(menu)
        return menu
    }()
    
    fileprivate var isOnScreen : Bool = false {
        didSet {
            if isOnScreen {
                self.addOrientationChangeNotification()
            } else {
                self.removeOrientationChangeNotification()
            }
        }
    }
    
    fileprivate lazy var tapGesture : UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(onBackgroudViewTapped(gesture:)))
        gesture.delegate = self
        return gesture
    }()
    
    fileprivate func showForSender(sender: UIView?, or senderFrame: CGRect?, with menuNameArray: [String]!, menuImageArray: [AnyObject]?, done: @escaping (NSInteger) -> Void, cancel:@escaping () -> Void){
        
        if sender == nil && senderFrame == nil {
            return
        }
        if menuNameArray.count == 0 {
            return
        }
        
        self.sender = sender
        self.senderFrame = senderFrame
        self.menuNameArray = menuNameArray
        self.menuImageArray = menuImageArray
        self.done = done
        self.cancel = cancel
        
        UIApplication.shared.keyWindow?.addSubview(self.backgroundView)
        
        self.adjustPostionForPopOverMenu()
    }
    
    fileprivate func adjustPostionForPopOverMenu() {
        self.backgroundView.frame = CGRect(x: 0, y: 0, width: UIScreen.ft_width(), height: UIScreen.ft_height())
        
        self.setupPopOverMenu()
        
        self.showIfNeeded()
    }
    
    fileprivate func setupPopOverMenu() {
        popOverMenu.transform = CGAffineTransform(scaleX: 1, y: 1)
        
        self.configurePopMenuFrame()
        
        popOverMenu.showWithAnglePoint(frame: popMenuFrame, menuNameArray: menuNameArray, menuImageArray: menuImageArray, arrowDirection: arrowDirection, done: { (selectedIndex: NSInteger) in
            self.isOnScreen = false
            self.doneActionWithSelectedIndex(selectedIndex: selectedIndex)
        })
        
        popOverMenu.setAnchorPoint(anchorPoint: self.getAnchorPointForPopMenu())
    }
    
    fileprivate func getAnchorPointForPopMenu() -> CGPoint {
        var anchorPoint = CGPoint(x: menuArrowPoint.x/popMenuFrame.size.width, y: 0)
        if arrowDirection == .down {
            anchorPoint = CGPoint(x: menuArrowPoint.x/popMenuFrame.size.width, y: 1)
        }
        return anchorPoint
    }
    
    fileprivate var senderRect : CGRect = CGRect.zero
    fileprivate var popMenuOriginX : CGFloat = 0
    fileprivate var popMenuFrame : CGRect = CGRect.zero
    fileprivate var menuArrowPoint : CGPoint = CGPoint.zero
    fileprivate var arrowDirection : FTPopOverMenuArrowDirection = .up
    fileprivate var popMenuHeight : CGFloat {
        return configuration.menuRowHeight * CGFloat(self.menuNameArray.count)
    }
    
    fileprivate func configureSenderRect() {
        if let sender = self.sender {
            if let superView = sender.superview {
                senderRect = superView.convert(sender.frame, to: backgroundView)
            }
        } else if let frame = senderFrame {
            senderRect = frame
        }
        senderRect.origin.y = min(UIScreen.ft_height(), senderRect.origin.y)
        
        if senderRect.origin.y + senderRect.size.height/2 < UIScreen.ft_height()/2 {
            arrowDirection = .up
        } else {
            arrowDirection = .down
        }
    }
    
    fileprivate func configurePopMenuOriginX() {
        var senderXCenter : CGPoint = CGPoint(x: senderRect.origin.x + (senderRect.size.width)/2, y: 0)
        let menuCenterX : CGFloat = configuration.menuWidth/2 + FT.DefaultXMargin
        var menuX : CGFloat = 0
        
        if senderXCenter.x + menuCenterX > UIScreen.ft_width() {
            senderXCenter.x = min(senderXCenter.x - (UIScreen.ft_width() - configuration.menuWidth - FT.DefaultXMargin), configuration.menuWidth - FT.DefaultMenuArrowWidth - FT.DefaultXMargin)
            menuX = UIScreen.ft_width() - configuration.menuWidth - FT.DefaultXMargin
            
        } else if senderXCenter.x - menuCenterX < 0 {
            senderXCenter.x = max(FT.DefaultMenuCornerRadius + FT.DefaultMenuArrowWidth, senderXCenter.x - FT.DefaultXMargin)
            menuX = FT.DefaultXMargin
            
        } else {
            senderXCenter.x = configuration.menuWidth/2
            menuX = senderRect.origin.x + (senderRect.size.width)/2 - configuration.menuWidth/2
        }
        
        popMenuOriginX = menuX
    }
    
    fileprivate func configurePopMenuFrame() {
        self.configureSenderRect()
        self.configureMenuArrowPoint()
        self.configurePopMenuOriginX()
        
        if arrowDirection == .up {
            popMenuFrame = CGRect(x: popMenuOriginX, y: (senderRect.origin.y + FT.DefaultYMargin), width: configuration.menuWidth, height: popMenuHeight)
            
        } else {
            popMenuFrame = CGRect(x: popMenuOriginX, y: (senderRect.origin.y - popMenuHeight + FT.DefaultYMargin), width: configuration.menuWidth, height: popMenuHeight)
        }
    }
    
    fileprivate func configureMenuArrowPoint() {
        var point : CGPoint = CGPoint(x: senderRect.origin.x + (senderRect.size.width)/2, y: 0)
        let menuCenterX : CGFloat = configuration.menuWidth/2 + FT.DefaultXMargin
        if senderRect.origin.y + senderRect.size.height/2 < UIScreen.ft_height()/2 {
            point.y = 20
        } else {
            point.y = 20
        }
        if point.x + menuCenterX > UIScreen.ft_width() {
            point.x = min(point.x - (UIScreen.ft_width() - configuration.menuWidth - FT.DefaultXMargin), configuration.menuWidth - FT.DefaultMenuArrowWidth - FT.DefaultXMargin)
        } else if point.x - menuCenterX < 0 {
            point.x = max(FT.DefaultMenuCornerRadius + FT.DefaultMenuArrowWidth, point.x - FT.DefaultXMargin)
        } else {
            point.x = configuration.menuWidth/2
        }
        menuArrowPoint = point
    }
    
    @objc fileprivate func onBackgroudViewTapped(gesture : UIGestureRecognizer) {
        self.dismiss()
    }
    
    fileprivate func showIfNeeded() {
        if self.isOnScreen == false {
            self.isOnScreen = true
            popOverMenu.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            UIView.animate(withDuration: FT.DefaultAnimationDuration, animations: {
                self.popOverMenu.alpha = 1
                self.popOverMenu.transform = CGAffineTransform(scaleX: 1, y: 1)
            })
        }
    }
    
    fileprivate func dismiss() {
        self.isOnScreen = false
        self.doneActionWithSelectedIndex(selectedIndex: -1)
    }
    
    fileprivate func doneActionWithSelectedIndex(selectedIndex: NSInteger) {
        UIView.animate(withDuration: FT.DefaultAnimationDuration,
                       animations: {
                        self.popOverMenu.alpha = 0
                        self.popOverMenu.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        }) { (isFinished) in
            if isFinished {
                self.backgroundView.removeFromSuperview()
                if selectedIndex < 0 {
                    if (self.cancel != nil) {
                        self.cancel()
                    }
                } else {
                    if self.done != nil {
                        self.done(selectedIndex)
                    }
                }
                
            }
        }
    }
    
}

extension FTPopOverMenu {
    
    fileprivate func addOrientationChangeNotification() {
        NotificationCenter.default.addObserver(self,selector: #selector(onChangeStatusBarOrientationNotification(notification:)),
                                               name: NSNotification.Name.UIApplicationDidChangeStatusBarOrientation,
                                               object: nil)
        
    }
    
    fileprivate func removeOrientationChangeNotification() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc fileprivate func onChangeStatusBarOrientationNotification(notification : Notification) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.2 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
            self.adjustPostionForPopOverMenu()
        })
    }
    
}

extension FTPopOverMenu: UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let touchPoint = touch.location(in: backgroundView)
        let touchClass : String = NSStringFromClass((touch.view?.classForCoder)!) as String
        if touchClass == "UITableViewCellContentView" {
            return false
        }else if CGRect(x: 0, y: 0, width: configuration.menuWidth, height: configuration.menuRowHeight).contains(touchPoint){
            // when showed at the navgation-bar-button-item, there is a chance of not respond around the top arrow, so :
            self.doneActionWithSelectedIndex(selectedIndex: 0)
            return false
        }
        return true
    }
    
}

private class FTPopOverMenuView: UIControl {
    
    fileprivate var menuNameArray : [String]!
    fileprivate var menuImageArray : [AnyObject]?
    fileprivate var arrowDirection : FTPopOverMenuArrowDirection = .up
    fileprivate var done : ((NSInteger) -> Void)!
    
    fileprivate lazy var configuration : FTConfiguration = {
        return FTConfiguration.shared
    }()
    
    lazy var menuTableView : UITableView = {
        let tableView = UITableView.init(frame: CGRect.zero, style: UITableViewStyle.plain)
        tableView.backgroundColor = FTConfiguration.shared.backgoundTintColor
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorColor = FTConfiguration.shared.menuSeparatorColor
        tableView.layer.cornerRadius = FTConfiguration.shared.cornerRadius
        tableView.clipsToBounds = true
        tableView.contentInset = FTConfiguration.shared.contentInsets
        return tableView
    }()
    
    fileprivate func showWithAnglePoint(frame: CGRect, menuNameArray: [String]!, menuImageArray: [AnyObject]!, arrowDirection: FTPopOverMenuArrowDirection, done: @escaping ((NSInteger) -> Void)) {
        
        self.frame = frame
        
        self.menuNameArray = menuNameArray
        self.menuImageArray = menuImageArray
        self.arrowDirection = arrowDirection
        self.done = done
        
        self.repositionMenuTableView()
        
        self.drawBackgroundLayerWithArrowPoint()
    }
    
    fileprivate func repositionMenuTableView() {
        self.menuTableView.frame = CGRect(x: 0, y: 0, width: self.frame.size.width, height: self.frame.size.height)
        self.menuTableView.reloadData()
        
        if menuTableView.frame.height < configuration.menuRowHeight * CGFloat(menuNameArray.count) {
            self.menuTableView.isScrollEnabled = true
        }else{
            self.menuTableView.isScrollEnabled = false
        }
        self.addSubview(self.menuTableView)
    }
    
    fileprivate lazy var backgroundLayer : CAShapeLayer = {
        let layer : CAShapeLayer = CAShapeLayer()
        return layer
    }()
    
    
    fileprivate func drawBackgroundLayerWithArrowPoint() {
        if self.backgroundLayer.superlayer != nil {
            self.backgroundLayer.removeFromSuperlayer()
        }
        
        backgroundLayer.path = self.getBackgroundPath().cgPath
        backgroundLayer.fillColor = configuration.backgoundTintColor.cgColor
        backgroundLayer.strokeColor = configuration.borderColor.cgColor
        backgroundLayer.lineWidth = configuration.borderWidth
        
        if configuration.localShadow {
            backgroundLayer.shadowColor = UIColor.black.cgColor
            backgroundLayer.shadowOffset = CGSize(width: 0.0, height: 2.0)
            backgroundLayer.shadowRadius = 20
            backgroundLayer.shadowOpacity = Float(FTConfiguration.shared.shadowAlpha)
            backgroundLayer.masksToBounds = false
            backgroundLayer.shouldRasterize = true
            backgroundLayer.rasterizationScale = UIScreen.main.scale
            
        }
        
        self.layer.insertSublayer(backgroundLayer, at: 0)
    }
    
    func getBackgroundPath() -> UIBezierPath {
        let radius : CGFloat = configuration.cornerRadius / 2
        
        let path : UIBezierPath = UIBezierPath(roundedRect: CGRect.init(x: 0, y: 0, width: self.bounds.size.width, height: self.bounds.size.height), cornerRadius: configuration.cornerRadius)
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.close()
        
        return path
    }
    
}

extension FTPopOverMenuView : UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return configuration.menuRowHeight
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if (self.done != nil) {
            self.done(indexPath.row)
        }
    }
    
}

extension FTPopOverMenuView : UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.menuNameArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell : FTPopOverMenuCell = FTPopOverMenuCell(style: .default, reuseIdentifier: FT.PopOverMenuTableViewCellIndentifier)
        var imageObject: AnyObject? = nil
        if menuImageArray != nil {
            if (menuImageArray?.count)! >= indexPath.row + 1 {
                imageObject = (menuImageArray?[indexPath.row])!
            }
        }
        cell.setupCellWith(menuName: menuNameArray[indexPath.row], menuImage: imageObject)
        if (indexPath.row == menuNameArray.count-1) {
            cell.separatorInset = UIEdgeInsetsMake(0, self.bounds.size.width, 0, 0)
        }else{
            cell.separatorInset = configuration.menuSeparatorInset
        }
        cell.selectionStyle = configuration.cellSelectionStyle;
        return cell
    }
    
}

