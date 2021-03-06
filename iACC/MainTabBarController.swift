//	
// Copyright © 2021 Essential Developer. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {
    private var friendsCache: FriendsCache!
    convenience init(friendCache: FriendsCache) {
		self.init(nibName: nil, bundle: nil)
        self.friendsCache = friendCache
		self.setupViewController()
	}

	private func setupViewController() {
		viewControllers = [
			makeNav(for: makeFriendsList(), title: "Friends", icon: "person.2.fill"),
			makeTransfersList(),
			makeNav(for: makeCardsList(), title: "Cards", icon: "creditcard.fill")
		]
	}
	
	private func makeNav(for vc: UIViewController, title: String, icon: String) -> UIViewController {
		vc.navigationItem.largeTitleDisplayMode = .always
		
		let nav = UINavigationController(rootViewController: vc)
		nav.tabBarItem.image = UIImage(
			systemName: icon,
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		nav.tabBarItem.title = title
		nav.navigationBar.prefersLargeTitles = true
		return nav
	}
	
	private func makeTransfersList() -> UIViewController {
		let sent = makeSentTransfersList()
		sent.navigationItem.title = "Sent"
		sent.navigationItem.largeTitleDisplayMode = .always
		
		let received = makeReceivedTransfersList()
		received.navigationItem.title = "Received"
		received.navigationItem.largeTitleDisplayMode = .always
		
		let vc = SegmentNavigationViewController(first: sent, second: received)
		vc.tabBarItem.image = UIImage(
			systemName: "arrow.left.arrow.right",
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		vc.title = "Transfers"
		vc.navigationBar.prefersLargeTitles = true
		return vc
	}
	
	private func makeFriendsList() -> ListViewController {
		let vc = ListViewController()
        
        vc.title = "Friends"
        
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(vc.addFriend))
        let isPremium = User.shared?.isPremium == true
            
        let api = FriendsAPIItemsServiceAdapter(
            select: {[weak vc] (friend) in
                vc?.select(friend: friend)
            },
            api: FriendsAPI.shared,
            cache: isPremium ? friendsCache: NullFriendsCache())
            .retry(2)
        let cache = FriendsCacheItemsServiceAdapter(select: {[weak vc] (friend) in
            vc?.select(friend: friend)
        }, cache: friendsCache)
        
        vc.service = isPremium ? api.withFallback(service: cache) : api
		return vc
	}
	
	private func makeSentTransfersList() -> ListViewController {
		let vc = ListViewController()
		
        vc.navigationItem.title = "Sent"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: vc, action: #selector(vc.sendMoney))
        vc.service = SentTransfersAPIItemsServiceAdapter(select: { [weak vc] (transfer) in
            vc?.select(transfer: transfer)
        }, api: TransfersAPI.shared).retry(1)
		return vc
	}
	
	private func makeReceivedTransfersList() -> ListViewController {
		let vc = ListViewController()
        
        vc.navigationItem.title = "Received"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: vc, action: #selector(vc.requestMoney))
        vc.service = ReceiveTransfersAPIItemsServiceAdapter(select: { [weak vc] (transfer) in
            vc?.select(transfer: transfer)
        }, api: TransfersAPI.shared).retry(1)
		return vc
	}
	
	private func makeCardsList() -> ListViewController {
		let vc = ListViewController()
        vc.title = "Cards"
        
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(vc.addCard))
        vc.service = CardsAPIItemsServiceAdapter(select: { [weak vc] (card) in
            vc?.select(card: card)
        }, api: CardAPI.shared)
		return vc
	}
	
}

struct FriendsAPIItemsServiceAdapter: ItemsService {
    let select: (Friend) -> Void
    let api: FriendsAPI
    let cache: FriendsCache
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadFriends {result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ (friends) in
                    cache.save(friends)
                    return friends.map { (friend) in
                        ItemViewModel(friend: friend) {
                            select(friend)
                        }
                    }
                }))
            }
        }
    }
}

class NullFriendsCache: FriendsCache {
    override func save(_ newFriends: [Friend]) {}
}

struct FriendsCacheItemsServiceAdapter: ItemsService {
    let select: (Friend) -> Void
    let cache: FriendsCache
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        cache.loadFriends {result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ (friends) in
                    return friends.map { (friend) in
                        ItemViewModel(friend: friend) {
                            select(friend)
                        }
                    }
                }))
            }
        }
    }
}

struct ItemsServiceWithFallback: ItemsService {
    let primary: ItemsService
    let fallback: ItemsService
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        primary.loadItems { (result) in
            switch result {
            case .success:
                completion(result)
            case .failure:
                fallback.loadItems(completion: completion)
            }
        }
    }
}

extension ItemsService {
    func withFallback(service: ItemsService) -> ItemsService {
        ItemsServiceWithFallback(primary: self, fallback: service)
    }
    func retry(_ n: Int) -> ItemsService {
        var service: ItemsService = self
        for _ in 0..<n {
            service = service.withFallback(service: self)
        }
        return service
    }
}

struct CardsAPIItemsServiceAdapter: ItemsService {
    let select: (Card) -> Void
    let api: CardAPI
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadCards { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ (cards) in
                    cards.map { (card) in
                        ItemViewModel(card: card) {
                            select(card)
                        }
                    }
                }))
            }
        }
    }
}
struct SentTransfersAPIItemsServiceAdapter: ItemsService {
    let select: (Transfer) -> Void
    let api: TransfersAPI
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadTransfers { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ (transfers) in
                    transfers
                        .filter { $0.isSender }
                        .map { (transfer) in
                            ItemViewModel(transfer: transfer, longDateStyle: true) {
                                select(transfer)
                            }
                        }
                }))
            }
        }
    }
}

struct ReceiveTransfersAPIItemsServiceAdapter: ItemsService {
    let select: (Transfer) -> Void
    let api: TransfersAPI
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadTransfers { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ (transfers) in
                    transfers
                        .filter { !$0.isSender }
                        .map { (transfer) in
                            ItemViewModel(transfer: transfer, longDateStyle: false) {
                                select(transfer)
                            }
                        }
                }))
            }
        }
    }
}
