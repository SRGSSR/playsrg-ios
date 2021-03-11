//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import XCTest

class ApplicationScreenshots: XCTestCase {
    
    var configuration: NSDictionary = [:]
    
    #if os(iOS)
    let sleepTime = UInt32(10)
    #else
    let sleepTime = UInt32(20)
    var tvOSTabBarIndex = 0
    #endif
    
    override func setUp() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
        
        continueAfterFailure = false
        
        #if os(iOS)
        if (UIDevice.current.userInterfaceIdiom == .pad) {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        else {
            XCUIDevice.shared.orientation = .portrait
        }
        #endif
        
        let testBundle = Bundle(for: type(of: self))
        if let path = testBundle.path(forResource: "Configuration", ofType: "plist") {
            configuration = NSDictionary(contentsOfFile: path) ?? [:]
        }
    }
    
    func testSnapshots() {
        let application = XCUIApplication()
        
        let tabBarsQuery = application.tabBars
        
        let videosTabBarItemQuery = tabBarsQuery.buttons[AccessibilityIdentifier.videosTabBarItem.rawValue]
        if videosTabBarItemQuery.exists {
            selectTabBarItem(videosTabBarItemQuery)
            
            sleep(sleepTime)
            snapshot("1-VideosHomeScreen")
        }
        
        let audiosTabBarItemQuery = tabBarsQuery.buttons[AccessibilityIdentifier.audiosTabBarItem.rawValue]
        if audiosTabBarItemQuery.exists {
            selectTabBarItem(audiosTabBarItemQuery)
            
            sleep(sleepTime)
            snapshot("2-AudiosHomeScreen")
        }
        
        let livestreamsTabBarItemQuery = tabBarsQuery.buttons[AccessibilityIdentifier.livestreamsTabBarItem.rawValue]
        if livestreamsTabBarItemQuery.exists {
            selectTabBarItem(livestreamsTabBarItemQuery)
            
            sleep(sleepTime)
            snapshot("3-LiveHomeScreen")
            
            #if os(iOS)
            let firstRadioCellQuery = application.tables.firstMatch.cells.element(boundBy: 1).collectionViews.cells.firstMatch
            if firstRadioCellQuery.exists {
                firstRadioCellQuery.tap()
                
                sleep(sleepTime)
                snapshot("4-RadioLivePlayer")
                
                let closeButtonQuery = application.buttons[AccessibilityIdentifier.closeButton.rawValue];
                if closeButtonQuery.exists {
                    closeButtonQuery.tap()
                }
            }
            #endif
        }
        
        let showsTabBarItemQuery = tabBarsQuery.buttons[AccessibilityIdentifier.showsTabBarItem.rawValue]
        if showsTabBarItemQuery.exists {
            selectTabBarItem(showsTabBarItemQuery)
            
            sleep(sleepTime)
            snapshot("5-ShowsScreen")
        }
        
        let searchText = configuration["SearchText"]
        let searchTabBarItemQuery = tabBarsQuery.buttons[AccessibilityIdentifier.searchTabBarItem.rawValue]
        if searchTabBarItemQuery.exists && searchText != nil {
            selectTabBarItem(searchTabBarItemQuery)
            
            let searchTextField = application.searchFields.firstMatch
            selectSearchTextField(searchTextField)
            searchTextField.typeText(searchText as! String)
            application.typeText("\n")
            
            sleep(sleepTime)
            snapshot("6-SearchScreen")
        }
    }
    
    func selectTabBarItem(_ tabBarItem :XCUIElement) {
        #if os(iOS)
        tabBarItem.tap()
        #else
        if tvOSTabBarIndex > 0 {
            let remote: XCUIRemote = XCUIRemote.shared
            remote.press(.right)
            remote.press(.select)
            sleep(2)
            remote.press(.up) // Keep focus on the tab bar item
        }
        tvOSTabBarIndex += 1
        #endif
    }
    
    func selectSearchTextField(_ searchTextField :XCUIElement) {
        #if os(iOS)
        searchTextField.tap()
        #endif
    }
}
