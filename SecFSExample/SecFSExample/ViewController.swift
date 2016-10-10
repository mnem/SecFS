//
//  ViewController.swift
//  SecFSExample
//
//  Created by David Wagner on 10/10/2016.
//  Copyright © 2016 David Wagner. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var imageView: UIImageView!

    fileprivate let fs = SecFSFileManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let data = fs?.dataForFilename(filename: "/screen.png"), let image = UIImage(data: data) else {
            return
        }
        
        imageView.image = image
    }
}

