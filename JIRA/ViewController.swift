//
//  ViewController.swift
//  JIRA
//
//  Created by Nayan Bhut on 2/23/23.
//

import Cocoa
import AppKit
import Combine

class ViewController: NSViewController {
    
    @IBOutlet weak var textView: NSTextView!
    @IBOutlet weak var button: NSButton!
    @IBOutlet weak var datePicker: NSDatePicker!
    @IBOutlet weak var spinner: NSProgressIndicator!
    @IBOutlet weak var textSuccess: NSTextField!
    @IBOutlet weak var textVersion: NSTextField!
    @IBOutlet weak var stackLogButtons: NSStackView!
    @IBOutlet weak var stackLogButton: NSStackView!

    @IBOutlet weak var textTicketId: NSTextView!
    @IBOutlet weak var textWorklogId: NSTextView!


    var currentVersion = "1.0"
    var arrIssueData: [String] = []
    var arrTicketData: [String] = []
    var currentIndex = 0
    var authToken = ""
    
    
    var cancellable: AnyCancellable?
    var setCancellable: Set<AnyCancellable> = []
    var failed: String = "0"
    var success: Int = 0
    var arrSuccessIds: [String] = []
    var arrFailedIds: [String] = []
    
//    #error Please update JIRA Configs
    // https://developer.atlassian.com/cloud/jira/platform/basic-auth-for-rest-apis/
    var baseURL = "https://your-domain.atlassian.net"
    var userName = "abc@test.com"
    var passwordToken =  "api_token"
    var arrProjectIDs = ["DEMO-1", "DEMO-2"] //Issue Ids
    
    enum APIFailureCondition: Error {
        case invalidServerResponse
    }
    
    struct Response {
        let value: String
        let response: URLResponse
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manageProgress(showSpinner: false)
        datePicker.dateValue = Date()
        textVersion.stringValue = "Version : \(currentVersion)"

        textTicketId.string = "Ticket Id"
        textWorklogId.string = "WorkLog Id"

//        stackLogButton.isHidden = true
//        stackLogButtons.isHidden = true

        authToken = getBasicToken()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.title = "JIRA Log"
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func btnSend(_ sender: NSButton) {
        print("Button Tapped")
        arrIssueData.removeAll()
        arrSuccessIds.removeAll()
        arrFailedIds.removeAll()
        arrTicketData.removeAll()
        separateData(arrData: textView.string.split(separator: "\n").map({String($0)}))
    }

    @IBAction func btnEdit(_ sender: NSButton) {

    }

    @IBAction func btnDelete(_ sender: NSButton) {
        callAPICombineDeleteLog(ticketID: textTicketId.string, workLogId: textWorklogId.string)
    }
}

extension ViewController {
    private func separateData(arrData: [String]) {
        var arrTempData:[String] = []
        arrData.forEach { strData in
            if checkRegex(strIssueText: strData) {
                print("String data is : ",strData)
                arrTicketData.append(strData)
                let strData = arrTempData.joined(separator: "\n")
                if !arrTempData.isEmpty {
                    arrIssueData.append(strData)
                }
                arrTempData = []
            }else {
                let data = "* " + strData
                arrTempData.append(data)
            }
        }
        
        let strData = arrTempData.joined(separator: "\n")
        arrIssueData.append(strData)
        arrTempData = []
        
        print(arrTicketData)
        print(arrIssueData)
        
        if arrTicketData.count == arrIssueData.count {
        } else {
            textView.string = "Updated"
        }
        callAPI()
    }
    
    private func callAPI() {
        if currentIndex == arrIssueData.count { return }
        
        let ticketDesc: String = arrIssueData[currentIndex]
        let ticket = arrTicketData[currentIndex]
        var ticketID = ""
        var ticketHour = ""
        
        //        guard let ticketID = ticket.split(separator: " ").first else { return } //ticketID = OID-3441
        
        let arrData = ticket.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if arrData.count == 2, let id = arrData.first, let hour = arrData.last {
            ticketID = String(id)
            
            var hoursdata = String(hour)
            hoursdata = hoursdata.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            ticketHour = hoursdata
            
        }else {
            return
        }
        print(ticketDesc)
        print(ticketID)
        print(ticketHour)
        
        let param = [
            "comment": ticketDesc,
            "started": getDate(selectedDate: datePicker.dateValue),
            "timeSpent": ticketHour
        ]
        callAPICombine(param: param, ticketID: ticketID)
    }

    private func callAPICombineDeleteLog(ticketID: String, workLogId: String) {
        let strUrl = "\(baseURL)/rest/api/2/issue/\(ticketID)/worklog/\(workLogId)"

        var request = URLRequest(url: URL(string: strUrl)!,timeoutInterval: Double.infinity)
        request.addValue(authToken, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        request.httpMethod = "DELETE"

        cancellable = URLSession.shared.dataTaskPublisher(for: request)
            .tryMap({
                if let response = $0.response as? HTTPURLResponse, response.statusCode == 204 {
                    return String(decoding: $0.data, as: UTF8.self)
                }else {
                    DispatchQueue.main.async {
                        let message = self.textSuccess.stringValue + "failed for \(ticketID)"
                        self.textSuccess.stringValue = message
                    }
                    throw(URLError(.badServerResponse))
                }
            })
            .sink(receiveCompletion: {completion in
                switch completion {
                case .failure(_):
                    print("Not Deleted")
                    break
                case .finished:
                    print("Finished")
                    break
                }
            }, receiveValue: {_ in
                print("Deleted")
            })

    }
    
    private func callAPICombine(param: [String: Any], ticketID: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: param, options: .prettyPrinted) else { return }
        let strUrl = "\(baseURL)/rest/api/2/issue/\(ticketID)/worklog"

        var request = URLRequest(url: URL(string: strUrl)!,timeoutInterval: Double.infinity)
        request.addValue(authToken, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpMethod = "POST"
        request.httpBody = data
        manageProgress(showSpinner: true)

        cancellable = URLSession.shared.dataTaskPublisher(for: request)
            .tryMap({
                if let response = $0.response as? HTTPURLResponse, response.statusCode == 201 {
                    return String(decoding: $0.data, as: UTF8.self)
                }else {
                    let message = self.textSuccess.stringValue + "failed for \(ticketID)"
                    self.textSuccess.stringValue = message
                    throw(URLError(.badServerResponse))
                }
            })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: {[weak self] completion in
                guard let `self` = self else {return}
                switch completion {
                case .failure(let error):
                    self.failed += "\(ticketID)  \n"
                    self.arrFailedIds.append(ticketID)
                    print(error.localizedDescription)
                    self.updateLabel()
                    break
                case .finished:
                    print("Finished")
                    break
                }
            }, receiveValue: {[weak self] value in
                guard let `self` = self else {return}
                print("data is", value)
                manageProgress(showSpinner: false)
                self.currentIndex += 1
                self.success += 1
                let id = "\(ticketID) => \(String(describing: try? (JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])?["id"] ?? "")) \n"
                self.arrSuccessIds.append(id)
                self.updateLabel()
                DispatchQueue.main.async {
                    self.callAPI()
                }
            })
        
    }
    
    private func updateLabel() {
        let successIds = arrSuccessIds.joined(separator: ", ")
        let failedIds = arrFailedIds.joined(separator: ", ")
        
        var wholeMessage = ""
        
        if success > 0 {
            wholeMessage.append("success : \(success) => \(successIds)")
        }
        
        if failed != "0" {
            wholeMessage.append("\nfailed : \(arrFailedIds.count) => \(failedIds)")
        }
        textSuccess.stringValue = wholeMessage

        stackLogButton.isHidden = false
        stackLogButtons.isHidden = false
    }
    
    private func manageProgress(showSpinner: Bool) {
        spinner.isHidden = !showSpinner
        spinner.startAnimation(self)
        
        button.isEnabled = !showSpinner
    }
    
    private func getDate(selectedDate: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"//2021-10-08T11:00:00.000Z
        let date = dateFormatter.string(from: selectedDate)
        return date
    }
    
    private func getBasicToken() -> String {
        let loginString = "\(userName):\(passwordToken)"
        
        guard let loginData = loginString.data(using: String.Encoding.utf8) else {
            return ""
        }
        let base64LoginString = loginData.base64EncodedString()
        
        print("Basic \(base64LoginString)")
        
        return "Basic \(base64LoginString)"
    }
}

//MARK: - Regex Validations
extension ViewController {
    private func checkRegex(strIssueText: String) -> Bool {
        let arrValidRegex = [
            getRegex()
        ]
        
        for regex in arrValidRegex {
            if matchesID(for: regex, in: strIssueText) {
                return true
            }
        }
        
        return false
    }
    
    private func matchesID(for regex: String, in text: String) -> Bool {
        if let result = text.range(of: regex, options: .regularExpression) {
            print("Regex ", regex)
            print("text ", text)
            print("Valid")
            print("\n")
            return true
        }else {
            return false
        }
    }
    
    private func getRegex() -> String {
        var ids = arrProjectIDs.map { projectID in
            return "(^\(projectID)-)"
        }.joined(separator: "|")
        
        ids = "(\(ids))"
        ids += "-*(\\d+) [(] {0,}(\\dh){0,} {0,}(\\d+m)[)]"
        return ids
    }
}
