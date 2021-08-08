//
// Copyright © 2021 Essential Developer. All rights reserved.
//

import UIKit

class ListViewController: UITableViewController {
	var items = [ItemViewModel]()
	
	var retryCount = 0
	var maxRetryCount = 0
	var shouldRetry = false
	
	var longDateStyle = false
	
	var fromReceivedTransfersScreen = false
	var fromSentTransfersScreen = false
	var fromCardsScreen = false
	var fromFriendsScreen = false
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		refreshControl = UIRefreshControl()
		refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
		
		if fromFriendsScreen {
			shouldRetry = true
			maxRetryCount = 2
			
			title = "Friends"
			
			navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addFriend))
			
		} else if fromCardsScreen {
			shouldRetry = false
			
			title = "Cards"
			
			navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCard))
			
		} else if fromSentTransfersScreen {
			shouldRetry = true
			maxRetryCount = 1
			longDateStyle = true

			navigationItem.title = "Sent"
			navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: self, action: #selector(sendMoney))

		} else if fromReceivedTransfersScreen {
			shouldRetry = true
			maxRetryCount = 1
			longDateStyle = false
			
			navigationItem.title = "Received"
			navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: self, action: #selector(requestMoney))
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if tableView.numberOfRows(inSection: 0) == 0 {
			refresh()
		}
	}
	
	@objc private func refresh() {
		refreshControl?.beginRefreshing()
		if fromFriendsScreen {
			FriendsAPI.shared.loadFriends { [weak self] result in
				DispatchQueue.mainAsyncIfNeeded {
                    self?.handleAPIResult(result.map({ (friends) in
                        if User.shared?.isPremium == true {
                            (UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate).cache.save(friends)
                        }
                        return friends.map { (friend) in
                            ItemViewModel(friend: friend) {
                                self?.select(friend: friend)
                            }
                        }
                    }))
				}
			}
		} else if fromCardsScreen {
			CardAPI.shared.loadCards { [weak self] result in
				DispatchQueue.mainAsyncIfNeeded {
                    self?.handleAPIResult(result.map({ (cards) in
                        cards.map { (card) in
                            ItemViewModel(card: card) {
                                self?.select(card: card)
                            }
                        }
                    }))
				}
			}
		} else if fromSentTransfersScreen || fromReceivedTransfersScreen {
			TransfersAPI.shared.loadTransfers { [weak self, longDateStyle, fromSentTransfersScreen] result in
				DispatchQueue.mainAsyncIfNeeded {
                    
                    self?.handleAPIResult(result.map({ (transfers) in
                        transfers
                            .filter { fromSentTransfersScreen ? $0.isSender : !$0.isSender }
                            .map { (transfer) in
                            ItemViewModel(transfer: transfer, longDateStyle: longDateStyle) {
                                self?.select(transfer: transfer)
                            }
                        }
                    }))
				}
			}
		} else {
			fatalError("unknown context")
		}
	}
	
	private func handleAPIResult(_ result: Result<[ItemViewModel], Error>) {
		switch result {
		case let .success(items):
			
			self.retryCount = 0
            self.items = items
			self.refreshControl?.endRefreshing()
			self.tableView.reloadData()
			
		case let .failure(error):
			if shouldRetry && retryCount < maxRetryCount {
				retryCount += 1
				
				refresh()
				return
			}
			
			retryCount = 0
			
			if fromFriendsScreen && User.shared?.isPremium == true {
				(UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate).cache.loadFriends { [weak self] result in
					DispatchQueue.mainAsyncIfNeeded {
						switch result {
						case let .success(items):
                            self?.items = items.map({ (item) in
                                ItemViewModel(friend: item, selection: {[weak self] in
                                    self?.select(friend: item)
                                })
                            })
							self?.tableView.reloadData()
							
						case let .failure(error):
                            self?.show(error: error)
						}
						self?.refreshControl?.endRefreshing()
					}
				}
			} else {
                show(error: error)
				self.refreshControl?.endRefreshing()
			}
		}
	}
    
	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		items.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let item = items[indexPath.row]
		let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ItemCell")
		cell.configure(item)
        
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let item = items[indexPath.row]
        item.select()
	}
	
	@objc func addCard() {
		show(AddCardViewController(), sender: self)
	}
	
	@objc func addFriend() {
		show(AddFriendViewController(), sender: self)
	}
	
	@objc func sendMoney() {
		show(SendMoneyViewController(), sender: self)
	}
	
	@objc func requestMoney() {
		show(RequestMoneyViewController(), sender: self)
	}
    
    func show(error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        showDetailViewController(alert, sender: self)
    }
    
}

struct ItemViewModel {
    let text: String
    let detailText: String
    let select: ()->Void
    init(_ item: Any, longDateStyle: Bool, selection: @escaping ()-> Void) {
        if let friend = item as? Friend {
            self = ItemViewModel(friend: friend, selection: selection)
        } else if let card = item as? Card {
            self = ItemViewModel(card: card, selection: selection)
        } else if let transfer = item as? Transfer {
            self = ItemViewModel(transfer: transfer, longDateStyle: longDateStyle, selection: selection)
        } else {
            fatalError("unknown item: \(item)")
        }
    }
}

extension ItemViewModel {
    init(friend: Friend, selection: @escaping ()-> Void) {
        text = friend.name
        detailText = friend.phone
        select = selection
    }
}

extension ItemViewModel {
    init(card: Card, selection: @escaping ()-> Void) {
        text = card.number
        detailText = card.holder
        select = selection
    }
}

extension ItemViewModel {
    init(transfer: Transfer, longDateStyle: Bool, selection: @escaping ()-> Void) {
        let numberFormatter = Formatters.number
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = transfer.currencyCode
        
        let amount = numberFormatter.string(from: transfer.amount as NSNumber)!
        text = "\(amount) • \(transfer.description)"
        
        let dateFormatter = Formatters.date
        if longDateStyle {
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            detailText = "Sent to: \(transfer.recipient) on \(dateFormatter.string(from: transfer.date))"
        } else {
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            detailText = "Received from: \(transfer.sender) on \(dateFormatter.string(from: transfer.date))"
        }
        select = selection
    }
}

extension UITableViewCell {
    func configure(_ vm: ItemViewModel) {
        textLabel?.text = vm.text
        detailTextLabel?.text = vm.detailText
		
	}
}
extension UIViewController {
    func select(friend: Friend) {
        let vc = FriendDetailsViewController()
        vc.friend = friend
        show(vc, sender: self)
    }
    
    func select(card: Card) {
        let vc = CardDetailsViewController()
        vc.card = card
        show(vc, sender: self)
    }
    
    func select(transfer: Transfer) {
        let vc = TransferDetailsViewController()
        vc.transfer = transfer
        show(vc, sender: self)
    }
}
