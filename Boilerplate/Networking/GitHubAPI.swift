//
//  GitHubAPI.swift
//  Boilerplate
//
//  Created by Leo on 2017/2/8.
//  Copyright © 2017年 Leo. All rights reserved.
//

import Foundation
import Moya

public func JSONResponseDataFormatter(_ data: Data) -> Data {
    do {
        let dataAsJSON = try JSONSerialization.jsonObject(with: data)
        let prettyData =  try JSONSerialization.data(withJSONObject: dataAsJSON, options: .prettyPrinted)
        return prettyData
    } catch {
        return data // fallback to original data if it can't be serialized.
    }
}


let requestClosure = { (endpoint: Endpoint<GitHub>, done: MoyaProvider.RequestResultClosure) in
    var request: URLRequest = endpoint.urlRequest!
    //request.httpShouldHandleCookies = false
    done(.success(request))
}


let endpointClosure = { (target: GitHub) -> Endpoint<GitHub> in
    let url = target.baseURL.appendingPathComponent(target.path).absoluteString
    let defaultEndpoint = MoyaProvider.defaultEndpointMapping(for: target)
    
    switch target {
    case .Token(let userString, let passwordString):
        let credentialData = "\(userString):\(passwordString)".data(using: String.Encoding.utf8)
        let base64Credentials = credentialData?.base64EncodedString()
        return defaultEndpoint.adding(newHTTPHeaderFields: ["Authorization": "Basic \(base64Credentials!)"])
    
    default:
        let environment = Environment()
        if !environment.tokenExists {
            return defaultEndpoint
        }
        
        return defaultEndpoint.adding(newHTTPHeaderFields: ["Authorization": "token \(environment.token!)"])
    }
    
}

public var GithubProvider = RxMoyaProvider<GitHub>(
    endpointClosure:endpointClosure,
    requestClosure:requestClosure,
    plugins: [NetworkLoggerPlugin(verbose: false, responseDataFormatter: JSONResponseDataFormatter)]
)


public func url(route: TargetType) -> String {
    return route.baseURL.appendingPathComponent(route.path).absoluteString
}

private extension String {
    var urlEscaped: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
    }
}

public enum GitHub {
    case Token(username: String, password: String)
    case RepoSearch(query: String, page:Int)
    case TrendingReposSinceLastWeek(language: String, page:Int)
    case Repo(fullname: String)
    case RepoReadMe(fullname: String)
    case Pulls(fullname: String)
    case Issues(fullname: String)
    case Commits(fullname: String)
    case User
}


extension GitHub: TargetType {
    public var baseURL: URL { return URL(string: "https://api.github.com")! }

    public var path: String {
        switch self {
        case .Token(_, _):
            return "/authorizations"
        case .RepoSearch(_,_),
             .TrendingReposSinceLastWeek(_,_):
            return "/search/repositories"
        case .Repo(let fullname):
            return "/repos/\(fullname)"
        case .RepoReadMe(let fullname):
            return "/repos/\(fullname)/readme"
        case .Pulls(let fullname):
            return "/repos/\(fullname)/pulls"
        case .Issues(let fullname):
            return "/repos/\(fullname)/issues"
        case .Commits(let fullname):
            return "/repos/\(fullname)/commits"
        case .User:
            return "/user"
            
        }
    }
    
    public var method: Moya.Method {
        switch self {
        case .Token(_, _):
            return .post
        case .RepoSearch(_),
             .TrendingReposSinceLastWeek(_,_),
             .Repo(_),
             .RepoReadMe(_),
             .Pulls(_),
             .Issues(_),
             .Commits(_),
             .User:
            return .get
        }
    }
    
    public var parameters: [String: Any]? {
        switch self {
        case .Token(_, _):
            return [
                "scopes": ["public_repo", "user"],
                "note": "(\(NSDate()))"
            ]
        case .Repo(_),
             .RepoReadMe(_),
             .User,
             .Pulls,
             .Issues,
             .Commits:
            return nil
        case .RepoSearch(let query,let page):
            return ["q": query.urlEscaped,"page":page]
        case .TrendingReposSinceLastWeek(let language,let page):
            let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return ["q" :"language:\(language) " + "created:>" + formatter.string(from: lastWeek!),
                    "sort" : "stars",
                    "order" : "desc",
                    "page":page
            ]
        }
    }
    
    var multipartBody: [MultipartFormData]? {
        return nil
    }
    
    public var parameterEncoding: ParameterEncoding {
    
        switch self {
        case .Token(_, _):
            return JSONEncoding.default
        default:
            return URLEncoding.default
        }
        
    }
    
    public var task: Task {
        return .request
    }
    
    public var sampleData: Data {
        return "".data(using: String.Encoding.utf8)!
    }

}