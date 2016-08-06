//
//  LogViewController.swift
//  UDApp
//
//  Created by Virl on 23/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

import UIKit

class LogViewController: UIViewController, UDJackLoggerDelegate {

	@IBOutlet weak var textView: UITextView!
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		AppModel.shared.udlogger.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
	
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
	
	@IBAction func clearLog(sender: AnyObject) {
		textView.text = ""
	}

	func scrollToBottom() {
		let range = NSMakeRange(textView.text.characters.count - 1, 1);
		textView.scrollRangeToVisible(range);
	}
	
	// MARK: - UDJackLoggerDelegate
	
	func logMessage(message: String)
	{
		textView.text = textView.text + message + "\n"
		
		
	}
}
