//
//  ChatUserListViewController.swift
//  RandCook
//
//  Created by Alexander on 17/12/15.
//  Copyright © 2015 RandCook. All rights reserved.
//

import UIKit
import Parse
import SVProgressHUD
import Firebase

struct RecentMessage {
    var message: String?
    var date: NSDate?
}

class ChatUserListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UISearchResultsUpdating, UISearchControllerDelegate, ChatUserCellDelegate {

    // MARK: - Outlets
    @IBOutlet weak var searchControllerContainer: UIView!
    @IBOutlet weak var tblUserList: UITableView!
    
    // MARK: - Properties
    var userArr = [User]()
    var filteredUserArr = [User]()
    var recentMessage = [RecentMessage]()
    var isSearching: Bool = false
    var chatNikName: String = ""
    
    var selectedUser: User?
    
    let searchController = UISearchController(searchResultsController: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Navigation Bar Setting
        
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationItem.title = "Messaging"
        
        addLeftMenuBarButtonItem()
        
        self.searchController.searchResultsUpdater = self
        self.searchController.dimsBackgroundDuringPresentation = false
        self.searchController.hidesNavigationBarDuringPresentation = false
        self.searchController.searchBar.barTintColor = UIColor.ColorFromRGB(0xD1570D, alpha: 1.0)
        self.definesPresentationContext = true
        self.searchController.searchBar.delegate = self
        self.searchController.delegate = self
        self.searchControllerContainer.addSubview(self.searchController.searchBar)
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if CONTACT_LIST_CHANGED == true
        {
            self.performSelector("extractUsers", withObject: nil, afterDelay: 0.1)
        }
        
        self.loadRecentMessage()
        self.tblUserList.reloadData()
    }
    
    // MARK: - UITableView DataSource and Delegate Methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.searchController.active && searchController.searchBar.text != ""
        {
            return filteredUserArr.count
        }
        return userArr.count
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellId = "ChatUserCell"
        
        var cell:ChatUserCell! = tableView.dequeueReusableCellWithIdentifier(cellId) as? ChatUserCell
        if cell == nil
        {
            cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: cellId) as? ChatUserCell
        }
        
        var user: User
        
        if self.searchController.active && self.searchController.searchBar.text != ""
        {
            user = self.filteredUserArr[indexPath.row]
        }
        else
        {
            user = userArr[indexPath.row]
        }
        cell.setUserInfo(user)
        cell.delegate = self
        return cell!
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        self.searchController.searchBar.resignFirstResponder()
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        self.selectedUser = self.userArr[indexPath.row]
        
        if CURRENT_USER?.chatNikName == nil || CURRENT_USER?.chatNikName?.isEmpty == true
        {
            let alert = UIAlertController(title: "CookWith", message: "Please specify a nikname for chat", preferredStyle: .Alert)
            
            alert.addTextFieldWithConfigurationHandler({ (textField) -> Void in
                textField.text = "\((CURRENT_USER?.fullname)!)"
            })
            
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
                let textField = alert.textFields![0] as UITextField
                let chatName = "\((textField.text)!)"
                
                SVProgressHUD.showWithStatus("Updating...")
                
                PFCloud.callFunctionInBackground("saveChatNikName", withParameters: ["chatNikName": chatName], block: { (object, error) -> Void in
                    if error == nil
                    {
                        SVProgressHUD.dismiss()
                        CURRENT_USER?.chatNikName = chatName
                        self.performSegueWithIdentifier("showChatView", sender: nil)
                    }
                    else
                    {
                        showRandBondErrorMessage("Update error! Please retry", parent: self)
                        print(error!.description)
                        return
                    }
                })
            }))
            
            self.presentViewController(alert, animated: true, completion: nil)
        }
        else
        {
            self.performSegueWithIdentifier("showChatView", sender: nil)
        }        
    }
    
    // MARK: - UISearchController Delegate Methods
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
//        let searchBar = searchController.searchBar
//        let scope = searchBar.scopeButtonTitles![searchBar.selectedScopeButtonIndex]
        self.filterContentForSearchText(self.searchController.searchBar.text!, scope: "All")
    }
    
    // MARK: - ChatUserCell Delegate Methods
    
    func didRequestVisitProfile(user: User?) {
        
        print("visit profile on chat user list")
        
        self.selectedUser = user
        self.performSegueWithIdentifier("showUserDetailView2", sender: nil)
    }
    
    // MARK: - Helpers
    
    func filterContentForSearchText(searchText: String, scope: String = "All") {
        self.filteredUserArr = userArr.filter { user in
            if user.chatNikName?.isEmpty == false
            {
                return (user.chatNikName?.lowercaseString.containsString(searchText.lowercaseString))!
            }
            else
            {
                return (user.fullname?.lowercaseString.containsString(searchText.lowercaseString))!
            }
        }
        
        self.tblUserList.reloadData()
    }
    
    func extractUsers()
    {
        SVProgressHUD.showWithStatus("Loading...")
        
        let query = CURRENT_USER?.friendsRelation?.query()
        query?.includeKey("reviewMark")
        
        query?.findObjectsInBackgroundWithBlock({ (objects: [PFObject]?, error: NSError?) -> Void in
            guard let users = objects as? [PFUser]
            else
            {
                print("No Users")
                return
            }
            self.userArr = (users as? [User])!
            SVProgressHUD.dismiss()
            
//            self.loadRecentMessage()
            
            self.tblUserList.reloadData()
            
            CONTACT_LIST_CHANGED = false
        })
    }
    
    func loadRecentMessage()
    {
        let firebase = Firebase(url: "https://randcook.firebaseIO.com/channels/Recent")
        firebase.observeEventType(.Value, withBlock: { (snapshot) -> Void in
            self.tblUserList.reloadData()
        })
    }
    
    // MARK: - Actions
    @IBAction func tapBtnSet(sender: AnyObject) {
        print("userlist set")
        
        for user in self.userArr
        {
            CURRENT_USER?.friendsRelation?.addObject(user)
        }
        
        CURRENT_USER?.saveInBackgroundWithBlock({ (succeeded, error) -> Void in
            if succeeded == true
            {
                SVProgressHUD.showSuccessWithStatus("Set Success!")
                    return
            }
            else
            {
                showRandBondErrorMessage((error?.description)!, parent: self)
                return
            }
        })
    }
    
    @IBAction func tapBtnGet(sender: AnyObject) {
        let query = CURRENT_USER?.friendsRelation?.query()
        query?.whereKeyExists("photo")
        
        query?.findObjectsInBackgroundWithBlock({ (objects, error) -> Void in
            if error == nil
            {
                self.userArr.removeAll()
                self.userArr = objects as! [User]
                self.tblUserList.reloadData()
            }
        })
    }
    
    // MARK: - Navigations
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showChatView"
        {
            let vc = segue.destinationViewController as? ChatViewController
            vc?.user = CURRENT_USER
            vc?.otherUser = self.selectedUser
            vc?.chatNikName = self.chatNikName
            vc?.senderToken = (CURRENT_USER?.chatChannelToken)!
            vc?.otherToken = self.selectedUser!.chatChannelToken!
        }
        else if segue.identifier == "showUserDetailView2"
        {
            let vc = segue.destinationViewController as? UserDetailViewController
            vc?.user = self.selectedUser
            vc?.fromController = "ChatList"
        }
    }
}
