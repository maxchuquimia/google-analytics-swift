//  Created by Max Chuquimia on 31/10/18.

import Foundation

protocol QueryRepresentable {
    var queryItems: [URLQueryItem] { get }
}

struct GAMeasurement {

    private static let collectURL = URL(string: "https://www.google-analytics.com/collect")!
    private static let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
    private(set) static var defaultValues: Models.Collect!
    static var log: ((String) -> ())?
    
    static func setup(with defaults: Models.Collect) {
        defaultValues = defaults
    }
    
    static func track(_ event: Request) {
        
        // Abuse URLComponents to give us an encoded query string
        var url = URLComponents(url: collectURL, resolvingAgainstBaseURL: false)!
        url.queryItems = defaultValues.queryItems + event.queryItems 
        guard let queryString = url.percentEncodedQuery  else { return }
        url.queryItems = nil
        
        // Make the request
        var request = URLRequest(url: collectURL, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 20.0)
        request.httpMethod = "POST"
        request.httpBody = (queryString + "\n").data(using: .utf8)
        
        
        session.dataTask(with: request) { (data, response, error) in
            
            if let error = error {
                log?("[Analytics] Error: \(error)")
            } else if let code = (response as? HTTPURLResponse)?.statusCode, code != 200 {
                log?("[Analytics] Error: \(code)")
            } else {
                log?("[Analytics] Sent \(queryString)")
            }
        }
        .resume()
    }
    
    struct Models {
        
        struct Collect: QueryRepresentable {
            
            enum AnalyticsVersion: String, QueryRepresentable {
                case one = "1"
                
                var queryItems: [URLQueryItem] {
                    return [URLQueryItem(name: "v", value: rawValue)]
                }
            }
            
            enum Identifier: QueryRepresentable {
                /// Anonymous identifier of the user
                case client(anonymousID: UUID)
                
                /// Known identifier associated with the user
                case user(ID: String)
                
                var queryItems: [URLQueryItem] {
                    switch self {
                    case .client(let id): return [URLQueryItem(name: "cid", value: id.uuidString)]
                    case .user(let id): return [URLQueryItem(name: "uid", value: id)]
                    }
                }
            }
            
            let queryItems: [URLQueryItem]
            
            init(version: AnalyticsVersion = .one, user: Identifier, trackingId: String, appInfo: AppInfo? = .default) {
                queryItems =
                    version.queryItems +
                    (appInfo?.queryItems ?? []) +
                    user.queryItems + [
                        URLQueryItem(name: "tid", value: trackingId)
                ]
            }
        }
        
        struct AppInfo: QueryRepresentable {
            
            static let `default` = AppInfo(
                name: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String,
                identifier: Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String,
                version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            )
            
            let queryItems: [URLQueryItem]
            
            init(name: String, identifier: String? = nil, version: String? = nil) {
                
                queryItems = [
                    URLQueryItem(name: "an", value: name),
                    URLQueryItem(name: "aid", value: identifier),
                    URLQueryItem(name: "av", value: version),
                ]
            }
        }
    }
    
    enum Request: QueryRepresentable {
        
        case event(category: String, action: String, label: String?, value: String?)
        case exception(description: String)
        case screen(name: String)
        
        var hitType: String {
            switch self {
            case .event: return "event"
            case .exception: return "exception"
            case .screen: return "screenview"
            }
        }
        
        var queryItems: [URLQueryItem] {
            return [ URLQueryItem(name: "t", value: hitType) ] + {
                switch self {
                    
                case let .event(category, action, label, value):
                    return [
                        URLQueryItem(name: "ec", value: category),
                        URLQueryItem(name: "ea", value: action),
                        URLQueryItem(name: "el", value: label),
                        URLQueryItem(name: "ev", value: value),
                    ]
                    
                case let .exception(description):
                    return [
                        URLQueryItem(name: "exd", value: description)
                    ]
                    
                case let .screen(name):
                    return [
                        URLQueryItem(name: "cd", value: name)
                    ]
                }
                }()
        }
        
        // ... add more as we need them
    }
}
