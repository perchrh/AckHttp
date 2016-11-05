import Foundation

// Based on example from https://thatthinginswift.com/write-your-own-api-clients-swift/

final class AckHttp {

    fileprivate func makeAsyncHttpRequest(request: NSMutableURLRequest, method: String, data: Data?, headers: [String:String]?, completion: @escaping (_ success:Bool, _ responseBody:Data?, _ errorObject:Error?) -> ()) {
        if (request.httpBody != nil || request.allHTTPHeaderFields != nil) {
            print("Warning, the body and headers set by the request will be overridden by " +
                    "the method parameters.")
        }

        self.addDataAndHeaders(request: request, method: method, data: data, headers: headers)

        let session = URLSession.shared
        session.dataTask(with: request as URLRequest) { (data: Data?, response: URLResponse?, error: Error?) in
            if let response = response as? HTTPURLResponse , response.statusCode / 100 == 2 {
                completion(true, data, error)
            } else {
                print("Error, received response code", (response as? HTTPURLResponse)?.statusCode ?? "unknown")
                if let data = data, let errorBody = String(data: data, encoding: String.Encoding.utf8) {
                    print("Error response was", errorBody)
                }
                completion(false, data, error)
            }
        }.resume()

    }

    fileprivate func makeSyncHttpRequest(request: NSMutableURLRequest, method: String, data: Data?, headers: [String:String]?) -> (success:Bool, responseBody:Data?, errorObject:Error?) {
        self.addDataAndHeaders(request: request, method: method, data: data, headers: headers)

        let session = URLSession.shared

        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)

        var retval: (success:Bool, responseBody:Data?, errorObject:Error?)? = nil
        session.dataTask(with: request as URLRequest) { (data: Data?, response: URLResponse?, error: Error?) in
            if let response = response as? HTTPURLResponse , response.statusCode / 100 == 2 {
                retval = (true, data, error)
            } else {
                retval = (false, data, error)

                print("Error, received response code", (response as? HTTPURLResponse)?.statusCode ?? "unknown")

                if let data = data, let errorBody = String(data: data, encoding: String.Encoding.utf8) {
                    print("Error response was", errorBody)
                }

            }

            semaphore.signal(); // mark as done, no more wait
        }.resume()

        semaphore.wait(timeout: DispatchTime.distantFuture)
        return retval!
    }

    fileprivate func addDataAndHeaders(request: NSMutableURLRequest, method: String, data: Data?, headers: [String:String]?) {
        request.httpMethod = method
        request.httpBody = data

        if let headers = headers {
            for (field, value) in headers {
                request.addValue(value, forHTTPHeaderField: field)
            }
        }
    }

    // Async methods
    func postAsync(request: NSMutableURLRequest, data: Data? = nil, headers: [String:String]? = nil, completion: @escaping (_ success:Bool, _ responseBody:Data?, _ errorObject:Error?) -> ()) {
        makeAsyncHttpRequest(request: request, method: "POST", data: data, headers: headers, completion: completion)
    }

    func putAsync(request: NSMutableURLRequest, data: Data? = nil, headers: [String:String]? = nil, completion: @escaping (_ success:Bool, _ responseBody:Data?, _ errorObject:Error?) -> ()) {
        makeAsyncHttpRequest(request: request, method: "PUT", data: data, headers: headers, completion: completion)
    }

    func getAsync(request: NSMutableURLRequest, data: Data? = nil, headers: [String:String]? = nil, completion: @escaping (_ success:Bool, _ responseBody:Data?, _ errorObject:Error?) -> ()) {
        makeAsyncHttpRequest(request: request, method: "GET", data: data, headers: headers, completion: completion)
    }

    func postSync(request: NSMutableURLRequest, data: Data? = nil, headers: [String:String]? = nil) -> (success:Bool, responseBody:Data?, errorObject:Error?) {
        return makeSyncHttpRequest(request: request, method: "POST", data: data, headers: headers)
    }

    func putSync(request: NSMutableURLRequest, data: Data? = nil, headers: [String:String]? = nil) -> (success:Bool, responseBody:Data?, errorObject:Error?) {
        return makeSyncHttpRequest(request: request, method: "PUT", data: data, headers: headers)
    }

    func getSync(request: NSMutableURLRequest, data: Data? = nil, headers: [String:String]? = nil) -> (success:Bool, responseBody:Data?, errorObject:Error?) {
        return makeSyncHttpRequest(request: request, method: "GET", data: data, headers: headers)
    }

    func createUrl(baseUrl: URL, pathComponents: [String], queryParams: Dictionary<String, String>? = nil) -> URL {
        var request = baseUrl

        let lastIndex = (pathComponents.count - 1)
        for (index, path) in pathComponents.enumerated() {
            let isNotLast = index != lastIndex
            request = request.appendingPathComponent(path, isDirectory: isNotLast)
        }

        var result = URLComponents(url: request, resolvingAgainstBaseURL: true)
        if let params = queryParams {
            var queryParameters = [URLQueryItem]();
            for (name, value) in params {
                queryParameters.append(URLQueryItem(name: name, value: value))
            }

            result!.queryItems = queryParameters
        }

        return result!.url!
    }

    func createFormDataFromFields(formFields:[String:String]) -> Data {
        var postData = ""
        var isFirst = true;
        for (key, value) in formFields {
            let prefix = isFirst ? "" : "&"
            let encodedKey:String = key.stringByAddingPercentEncodingForFormData(true)!
            let encodedValue:String = value.stringByAddingPercentEncodingForFormData(true)!
            postData += "\(prefix)\(encodedKey)=\(encodedValue)"
            isFirst = false
        }

        return postData.data(using: String.Encoding.utf8)!
    }

    // example usage
    func dummyAsyncServiceCall(_ email: String, password: String, completion: @escaping (_ success:Bool, _ data:Data?, _ error:AnyObject?) -> ()) {
        let queryParameters = ["email": email, "password": password]
        let pathComponents = ["auth", "local"]
        let baseUrl = URL(string: "http://api.mydomain.com:8074/")!

        let url = createUrl(baseUrl:baseUrl, pathComponents: pathComponents, queryParams: queryParameters)
        let request = NSMutableURLRequest(url: url)
        postAsync(request: request) { (success, data, error) -> Void in
            if success {
                completion(true, data, error as AnyObject?)
            } else {
                completion(false, data, error as AnyObject?)
            }
        }
    }

}
