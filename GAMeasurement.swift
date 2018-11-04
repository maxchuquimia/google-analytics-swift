//  Created by Max Chuquimia on 31/10/18.

import Foundation

protocol QueryRepresentable {
    var queryItems: [URLQueryItem] { get }
}

struct GAMeasurement {

    private static let batchURL = URL(string: "https://www.google-analytics.com/batch")!
    private static let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
    private(set) static var defaultValues: Models.Collect!
    static var log: ((String) -> ())?
    
    private static var queuedHits: [String] = [] {
        didSet {
            if oldValue.isEmpty {
                // If there was nothing in the array, we schedule sending in a sec
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.sendQueuedData()
                }
            }
        }
    }
    
    static func setup(with defaults: Models.Collect) {
        defaultValues = defaults
    }
    
    static func track(_ event: Request, custom: Models.Custom? = nil) {
        
        // Abuse URLComponents to give us an encoded query string
        var url = URLComponents(url: batchURL, resolvingAgainstBaseURL: false)!
        var queryItems = defaultValues.queryItems + event.queryItems
        
        if let c = custom {
            queryItems = queryItems + c.queryItems
        }
        
        url.queryItems = queryItems.filter({ $0.value != nil })
        
        guard let queryString = url.percentEncodedQuery  else { return }
        url.queryItems = nil
        
        queuedHits.append(queryString)
    }
    
    private static func sendQueuedData() {
        
        guard !queuedHits.isEmpty else { return }
        
        let bodyString = queuedHits.joined(separator: "\n") + "\n" // Seems like we need a new line at the end?
        queuedHits = []
        
        var request = URLRequest(url: batchURL, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 20.0)
        request.httpMethod = "POST"
        request.httpBody = bodyString.data(using: .utf8)
        
        
        session.dataTask(with: request) { (data, response, error) in
            
            if let error = error {
                log?("Error: \(error)")
            } else if let code = (response as? HTTPURLResponse)?.statusCode, code != 200 {
                log?("Error: \(code)")
            } else {
                log?("Sent data:\n\(bodyString)")
            }
        }
        .resume()
    }
    
    struct Models {

        struct Custom: QueryRepresentable {
            let dimensionIndex: Int
            let dimensionValue: String
            let metricIndex: Int
            let metricValue: Int
            
            var queryItems: [URLQueryItem] {
                return [
                    URLQueryItem(name: "cd\(dimensionIndex)", value: dimensionValue),
                    URLQueryItem(name: "cm\(metricIndex)", value: "\(metricValue)"),
                ]
            }
        }

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
            
            init(version: AnalyticsVersion = .one, user: Identifier, trackingId: String, datasource: String? = "app", userLanguage: String? = Locale.current.languageCode, appInfo: AppInfo? = .default) {
                queryItems =
                    version.queryItems +
                    (appInfo?.queryItems ?? []) +
                    user.queryItems + [
                        URLQueryItem(name: "tid", value: trackingId),
                        URLQueryItem(name: "ds", value: datasource),
                        URLQueryItem(name: "ul", value: userLanguage)
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
        
        case event(category: String, action: String, label: String?, value: Int?)
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
                        URLQueryItem(name: "ev", value: value == nil ? nil : "\(value!)"),
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
