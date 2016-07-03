import Foundation

// Based on example from https://thatthinginswift.com/write-your-own-api-clients-swift/

class AckHttp {

    private func makeAsyncHttpRequest(request: NSMutableURLRequest, method: String, data: NSData?, headers: [String:String]?, completion: (success:Bool, responseBody:NSData?, errorObject:AnyObject?) -> ()) {

        self.addDataAndHeaders(request, method: method, data: data, headers: headers)

        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())

        session.dataTaskWithRequest(request) {
            (data, response, error) -> Void in
            if let response = response as? NSHTTPURLResponse where response.statusCode / 100 == 2 {
                completion(success: true, responseBody: data, errorObject: error)
            } else {
                completion(success: false, responseBody: data, errorObject: error)
            }
        }.resume()
    }

    private func makeSyncHttpRequest(request: NSMutableURLRequest, method: String, data: NSData?, headers: [String:String]?) -> (success:Bool, responseBody:NSData?, errorObject:AnyObject?) {

        self.addDataAndHeaders(request, method: method, data: data, headers: headers)

        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())

        let semaphore: dispatch_semaphore_t = dispatch_semaphore_create(0)

        var retval: (success:Bool, responseBody:NSData?, errorObject:AnyObject?)? = nil
        session.dataTaskWithRequest(request) {
            (data, response, error) -> Void in
            if let response = response as? NSHTTPURLResponse where response.statusCode / 100 == 2 {
                retval = (success: true, responseBody: data, errorObject: error)
            } else {
                retval = (success: false, responseBody: data, errorObject: error)
            }

            dispatch_semaphore_signal(semaphore); // mark as done, no more wait
        }.resume()

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        return retval!
    }

    private func addDataAndHeaders(request: NSMutableURLRequest, method: String, data: NSData?, headers: [String:String]?) {
        request.HTTPMethod = method
        request.HTTPBody = data

        if let headers = headers {
            for (field, value) in headers {
                request.addValue(value, forHTTPHeaderField: field)
            }
        }
    }

    func postAsync(request: NSMutableURLRequest, data: NSData? = nil, headers: [String:String]? = nil, completion: (success:Bool, responseBody:NSData?, errorObject:AnyObject?) -> ()) {
        makeAsyncHttpRequest(request, method: "POST", data: data, headers: headers, completion: completion)
    }

    func putAsync(request: NSMutableURLRequest, data: NSData? = nil, headers: [String:String]? = nil, completion: (success:Bool, responseBody:NSData?, errorObject:AnyObject?) -> ()) {
        makeAsyncHttpRequest(request, method: "PUT", data: data, headers: headers, completion: completion)
    }

    func getAsync(request: NSMutableURLRequest, data: NSData? = nil, headers: [String:String]? = nil, completion: (success:Bool, responseBody:NSData?, errorObject:AnyObject?) -> ()) {
        makeAsyncHttpRequest(request, method: "GET", data: data, headers: headers, completion: completion)
    }

    func postSync(request: NSMutableURLRequest, data: NSData? = nil, headers: [String:String]? = nil) -> (success:Bool, responseBody:NSData?, errorObject:AnyObject?) {
        return makeSyncHttpRequest(request, method: "POST", data: data, headers: headers)
    }

    func putSync(request: NSMutableURLRequest, data: NSData? = nil, headers: [String:String]? = nil) -> (success:Bool, responseBody:NSData?, errorObject:AnyObject?) {
        return makeSyncHttpRequest(request, method: "PUT", data: data, headers: headers)
    }

    func getSync(request: NSMutableURLRequest, data: NSData? = nil, headers: [String:String]? = nil) -> (success:Bool, responseBody:NSData?, errorObject:AnyObject?) {
        return makeSyncHttpRequest(request, method: "GET", data: data, headers: headers)
    }

    func createUrl(baseUrl: NSURL, pathComponents: [String], queryParams: Dictionary<String, String>? = nil) -> NSURL {
        var request = baseUrl

        let lastIndex = pathComponents.count.predecessor()
        for (index, path) in pathComponents.enumerate() {
            let isNotLast = index != lastIndex
            request = request.URLByAppendingPathComponent(path, isDirectory: isNotLast)
        }

        let result = NSURLComponents(URL: request, resolvingAgainstBaseURL: true)
        if let params = queryParams {
            var queryParameters = [NSURLQueryItem]();
            for (name, value) in params {
                queryParameters.append(NSURLQueryItem(name: name, value: value))
            }

            result!.queryItems = queryParameters
        }

        return result!.URL!
    }

    // example usage
    func dummyAsyncServiceCall(email: String, password: String, completion: (success:Bool, message:String?) -> ()) {
        let queryParameters = ["email": email, "password": password]
        let pathComponents = ["auth", "local"]
        let baseUrl = ConaxConnectSettings.CONNECT_PORTAL_BASE_URL

        let url = createUrl(baseUrl, pathComponents: pathComponents, queryParams: queryParameters)
        let request = NSMutableURLRequest(URL: url)
        postAsync(request) {
            (success, data, error) -> () in
            dispatch_async(dispatch_get_main_queue(), {
                () -> Void in
                if success {
                    completion(success: true, message: nil)
                } else {
                    if let error = error {
                        completion(success: false, message: "\(error)")
                    } else {
                        completion(success: false, message: "there was an error")
                    }
                }
            })
        }
    }

}
