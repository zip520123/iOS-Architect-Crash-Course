//	
// Copyright © 2021 Essential Developer. All rights reserved.
//

import Foundation

class APIClient {
    static let shared = APIClient()
}
extension APIClient {
    func loadFeed() {
        
    }
}
extension APIClient {
    func login(completion: (LoggedInUser)-> Void) {
        
    }
}
struct LoggedInUser {}

struct LoginViewModel {
    let loginFunc: (((LoggedInUser)-> Void)->Void)
    func login() {
        loginFunc { user in
            
        }
    }
}
struct FeedClient {
    let api: APIClient
    func loadFeed() {
        
    }
}

let loginViewModel = LoginViewModel(loginFunc: APIClient.shared.login)
