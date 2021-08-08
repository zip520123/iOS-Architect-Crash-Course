//	
// Copyright © 2021 Essential Developer. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {
    private var friendCache: FriendsCache?
    convenience init(friendCache: FriendsCache) {
		self.init(nibName: nil, bundle: nil)
        self.friendCache = friendCache
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
		vc.fromFriendsScreen = true
        vc.shouldRetry = true
        vc.maxRetryCount = 2
        
        vc.title = "Friends"
        
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(vc.addFriend))
        let isPremium = User.shared?.isPremium == true
        vc.service = FriendsAPIItemsServiceAdapter(
            select: {[weak vc] (friend) in
                vc?.select(friend: friend)
            },
            api: FriendsAPI.shared,
            cache: isPremium ? (UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate).cache: NullFriendsCache())
		return vc
	}
	
	private func makeSentTransfersList() -> ListViewController {
		let vc = ListViewController()
		vc.fromSentTransfersScreen = true
		return vc
	}
	
	private func makeReceivedTransfersList() -> ListViewController {
		let vc = ListViewController()
		vc.fromReceivedTransfersScreen = true
		return vc
	}
	
	private func makeCardsList() -> ListViewController {
		let vc = ListViewController()
		vc.fromCardsScreen = true
        vc.shouldRetry = false
        
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
