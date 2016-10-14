//
//  LogViewController.swift
//  UDApp
//
//  Created by Virl on 23/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

import UIKit

class LogViewController: UIViewController, FormLoggerDelegate {

	@IBOutlet weak var textView: UITextView!

	private let formatter = NSDateFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()

	    formatter.dateStyle = .NoStyle
	    formatter.timeStyle = .MediumStyle

		AppModel.shared.formLogger.updateDelegate(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
	
    // MARK: - Navigation

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {

	}

	@IBAction func clearLog(sender: AnyObject) {
		textView.text = ""
	}

	func scrollToBottom() {
		let range = NSMakeRange(textView.text.characters.count - 1, 1);
		textView.scrollRangeToVisible(range);
	}
	
	// MARK: - UDLoggerDelegate
	
	func logMessage(message: String)
	{
		textView.text = textView.text + message + "\n"// + "\n"
	}
}
