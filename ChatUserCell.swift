//
//  ChatUserCell.swift
//  RandCook
//
//  Created by Alexander on 18/12/15.
//  Copyright © 2015 RandCook. All rights reserved.
//

import UIKit
import Firebase

protocol ChatUserCellDelegate {
    
    func didRequestVisitProfile(user: User?)
}

class ChatUserCell: UITableViewCell {
    
    // Outlets
    
    @IBOutlet weak var ivwPhoto: UIImageView!
    @IBOutlet weak var lblPhotoPlaceholder: UILabel!
    @IBOutlet weak var photoLoadActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var lblUsername: UILabel!
    @IBOutlet weak var lblLastMessage: UILabel!
    @IBOutlet weak var lblTime: UILabel!
    @IBOutlet weak var userStatusView: UIView!
    
    // Properties
    var user: User?
    var delegate: ChatUserCellDelegate? = nil

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setUserInfo(user: User?)
    {
        if user != nil
        {
            self.user = user
            
            var chatNikName = user?.chatNikName
            if chatNikName == nil || chatNikName?.isEmpty == true
            {
                chatNikName = user?.fullname
            }
            self.lblUsername.text = chatNikName
            
            if user?.photo != nil
            {
                self.photoLoadActivityIndicator.startAnimating()
                user?.photo?.getDataInBackgroundWithBlock({ (data, error) -> Void in
                    if error == nil
                    {
                        let image = UIImage(data: data!)
                        self.ivwPhoto.image = image
                        self.photoLoadActivityIndicator.stopAnimating()
                        self.lblPhotoPlaceholder.hidden = true
                    }
                })
            }
            else
            {
                let name = user?.fullname
                let nameLength = name!.characters.count
                let initials : String? = name!.substringToIndex(name!.startIndex.advancedBy(min(3, nameLength)))
                self.lblPhotoPlaceholder.hidden = false
                self.lblPhotoPlaceholder.text = initials
                self.ivwPhoto.image = nil
            }
            
            self.userStatusView.backgroundColor = self.user?.onlineStatus == 1 ? UIColor.orangeColor() : UIColor.lightGrayColor()
            self.setLastMessage()
        }
    }
    
    func setLastMessage()
    {
        let chatChannel = getChatChannel((self.user!.chatChannelToken)!, token2: (CURRENT_USER?.chatChannelToken)!)
        let recentFirebase = Firebase(url: "https://randcook.firebaseIO.com/channels/Recent/\(chatChannel)")
        
        recentFirebase.queryLimitedToLast(1).observeSingleEventOfType(.Value, withBlock: { (snapshot) -> Void in
            if !(snapshot.value is NSNull)
            {
                let item = snapshot.value as? Dictionary<String, AnyObject>
                let value = item?.first!.1 as! Dictionary<String, AnyObject>
                
                let dateString = value["date"] as! String
                let formatter = NSDateFormatter()
                formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                formatter.dateFormat = "yyyy-MM-dd hh:mm:ss a"
                let date = formatter.dateFromString(dateString)
                
                let seconds = NSDate().timeIntervalSinceDate(date!)

                self.lblLastMessage.text = value["message"]! as? String
                self.lblTime.text = TimeElapsed(seconds)
            }
            else
            {
                self.lblLastMessage.text = ""
            }
        })
    }
    
    func setLastMessage(message: String)
    {
        self.lblLastMessage.text = message
    }
    
    //MARK: - Actions
    
    @IBAction func tapBtnVisitProfile(sender: AnyObject) {
        self.delegate?.didRequestVisitProfile(self.user)
    }
    

}
