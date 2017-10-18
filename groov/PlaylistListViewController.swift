//
//  PlaylistListViewController.swift
//  groov
//
//  Created by PilGwonKim_MBPR on 2016. 7. 20..
//  Copyright © 2016년 PilGwonKim. All rights reserved.
//

import UIKit
import RealmSwift

class PlaylistListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, VideoListViewControllerDelegate, GRAlertViewDelegate {
    var playlistArray: Array<Playlist> = []
    @IBOutlet var playlistTableView: UITableView!
    @IBOutlet var blankView: UIView!
    @IBOutlet var footerView: UIView!
    
    var addFolderAlertView: GRAlertView!
    var addFolderBackgroundView: UIControl!
    
    var realmClear: Bool = false
    fileprivate var clearRealmObserver: NSObjectProtocol?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.setNavigationBar()
        
        if self.realmClear == true {
            self.realmClear = false
            self.loadPlaylists()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
        self.navigationItem.title = "Folder List"
        self.playlistTableView.backgroundColor = GRVColor.backgroundColor
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: .UIKeyboardWillChangeFrame, object: nil)
        
        self.addObserver()
        self.initComponents()
        self.loadPlaylists()
    }
    
    func setNavigationBar() {
        // set navigation title text font
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: 15),
            NSAttributedStringKey.foregroundColor: UIColor.white
        ]
        
        // set navigation clear
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.barTintColor = GRVColor.backgroundColor
        self.navigationController?.navigationBar.isTranslucent = false
        
        footerView.backgroundColor = GRVColor.backgroundColor
    }
    
    func addObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(realmCleared), name: NSNotification.Name(rawValue: "clear_realm"), object: nil)
    }
    
    @objc func realmCleared() {
        self.realmClear = true
    }
    
    func initComponents() {
        self.initAlertView()
    }
    
    func initAlertView() {
        if let subviewArray = Bundle.main.loadNibNamed("GRAlertView", owner: self, options: nil) {
            addFolderAlertView = subviewArray[0] as! GRAlertView
            addFolderAlertView.center = self.view.center
            addFolderAlertView.delegate = self
            addFolderAlertView.initViews()
        }
    }
    
    func alertViewAddButtonClicked(title: String) {
        self.addPlaylist(title)
    }
    
    func loadPlaylists() {
        let realm = try! Realm()
        self.playlistArray = Array(realm.objects(Playlist.self).sorted(byKeyPath: "order"))
        self.setBlankViewHidden()
        self.playlistTableView.reloadData()
    }
    
    func setBlankViewHidden() {
        var hidden: Bool = true
        if self.playlistArray.count == 0 {
            hidden = false
        }
        self.blankView.isHidden = hidden
        self.playlistTableView.isHidden = !hidden
    }
    
    func addPlaylist(_ title: String) {
        let realm = try! Realm()
        let p = Playlist(value: ["title": title, "order": self.playlistArray.count])
        try! realm.write {
            realm.add(p)
        }
        
        self.playlistArray.append(p)
        self.setBlankViewHidden()
        self.playlistTableView.beginUpdates()
        let indexPath = IndexPath(row: self.playlistArray.count-1, section: 0)
        self.playlistTableView.insertRows(at: [indexPath], with: .automatic)
        self.playlistTableView.endUpdates()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.playlistArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCellIdentifier", for: indexPath) as! PlaylistTableViewCell
        cell.initCell(self.playlistArray[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let videoListVC = self.storyboard?.instantiateViewController(withIdentifier: "VideoListViewController") as! VideoListViewController
        videoListVC.playlist = playlistArray[indexPath.row]
        videoListVC.delegate = self
        self.navigationController?.pushViewController(videoListVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction: UITableViewRowAction = UITableViewRowAction.init(style: .normal, title: "삭제하기") { (action, indexPath) in
            self.tableView(self.playlistTableView, commit: .delete, forRowAt: indexPath)
        }
        deleteAction.backgroundColor = GRVColor.tableviewRowDeleteColor
        
        return [deleteAction]
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let playlist = self.playlistArray[indexPath.row]
            let targetId = playlist.id
            self.playlistArray.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            let realm = try! Realm()
            // delete target playlist's videos
            for v in Array(realm.objects(Video.self).filter("playlistId = %@", playlist.id).sorted(byKeyPath: "order")) {
                try! realm.write {
                    realm.delete(v)
                }
            }
            // delete target playlist
            if let pl = realm.objects(Playlist.self).filter("id = %@", targetId).first {
                try! realm.write {
                    realm.delete(pl)
                }
            }
            // reorder all playlist
            for (idx, pl) in Array(realm.objects(Playlist.self).sorted(byKeyPath: "order")).enumerated() {
                try! realm.write {
                    pl.order = idx
                }
            }
            self.playlistArray = Array(realm.objects(Playlist.self).sorted(byKeyPath: "order"))
            self.setBlankViewHidden()
        }
    }
    
    @IBAction func addButtonClicked() {
        addFolderAlertView.show()
    }
    
    @IBAction func showSettingsVC() {
        let settingsVC = self.storyboard?.instantiateViewController(withIdentifier: "SettingsViewController") as! SettingsViewController
        let navController = UINavigationController.init(rootViewController: settingsVC)
        self.present(navController, animated: true, completion: nil)
    }
    
    @IBAction func showSideMenu() {
        let center = NotificationCenter.default
        center.post(Notification(name: Notification.Name(rawValue: ContainerViewController.Notifications.toggleMenu), object: self))
    }
    
    func recentVideoChanged(_ playlist: Playlist) {
        if let index = self.playlistArray.find({$0 == playlist}) {
            self.playlistArray[index] = playlist
            self.playlistTableView.beginUpdates()
            let indexPath = IndexPath(row: index, section: 0)
            self.playlistTableView.reloadRows(at: [indexPath], with: .automatic)
            self.playlistTableView.endUpdates()
        }
    }
    
    @objc func keyboardWillChangeFrame(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            self.addFolderAlertView.center = CGPoint(x: self.addFolderAlertView.center.x, y: keyboardSize.origin.y / 2)
        }
    }
    
}
