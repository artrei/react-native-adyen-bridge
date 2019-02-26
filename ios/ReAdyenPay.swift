import Foundation
import Adyen

@objc(ReAdyenPay)
class ReAdyenPay: RCTEventEmitter, CheckoutViewControllerDelegate {
	override func supportedEvents() -> [String]! {
		return ["onCheckoutDone", "url"]
	}

	fileprivate var checkoutDict = Dictionary<String, Any>()
	fileprivate var verifyDict = Dictionary<String, Any>()
	fileprivate var checkoutURL = String()
	fileprivate var verifyURL = String()
	fileprivate var checkoutAPIKeyName = String()
	fileprivate var checkoutAPIKeyValue = String()
	fileprivate var adyenPayload = String()
	fileprivate var adyenResult = String()
	fileprivate var urlCompletion: URLCompletion?

	@objc(applicationRedirect:)
	func applicationRedirect(_ url: URL) {
		urlCompletion?(url)
	}

	@objc(showCheckout:)
	func showCheckout(_ checkoutNSDict: NSDictionary) {
		checkoutDict = (checkoutNSDict as? [String : Any])!
		
		if (checkoutDict["checkoutURL"] != nil) {
			checkoutURL = (checkoutNSDict["checkoutURL"] as? String)!
			checkoutDict.removeValue(forKey: "checkoutURL")
		}
		
		if (checkoutDict["verifyURL"] != nil) {
			verifyURL = (checkoutNSDict["verifyURL"] as? String)!
			checkoutDict.removeValue(forKey: "verifyURL")
		}

		if (checkoutDict["checkoutAPIKeyName"] != nil) {
			checkoutAPIKeyName = (checkoutNSDict["checkoutAPIKeyName"] as? String)!
			checkoutDict.removeValue(forKey: "checkoutAPIKeyName")
		}

		if (checkoutDict["checkoutAPIKeyValue"] != nil) {
		 	checkoutAPIKeyValue = (checkoutNSDict["checkoutAPIKeyValue"] as? String)!
			checkoutDict.removeValue(forKey: "checkoutAPIKeyValue")
		}

		DispatchQueue.main.async {
			let hostViewController = UIApplication.shared.keyWindow?.rootViewController

			self.startCheckout(hostViewController!)
		}
	}

	func startCheckout(_ hostViewController: UIViewController) {
		let checkoutViewController = CheckoutViewController(delegate: self)

		hostViewController.present(checkoutViewController, animated: true)
	}

	func checkoutViewController(_ controller: CheckoutViewController,
			requiresPaymentDataForToken token: String,
			completion: @escaping DataCompletion) {
		let url = URL(string: checkoutURL)!
		var request = URLRequest(url: url)

		request.httpMethod = "POST"
		checkoutDict["token"] = token
		request.httpBody = try? JSONSerialization.data(withJSONObject: checkoutDict, options: [])

		request.allHTTPHeaderFields = [
			"Content-Type": "application/json"
		]

		if (!checkoutAPIKeyName.isEmpty && !checkoutAPIKeyValue.isEmpty) {
			request.addValue(checkoutAPIKeyValue, forHTTPHeaderField: checkoutAPIKeyName)
		}

		let session = URLSession(configuration: .default)
		session.dataTask(with: request) { data, response, error in
			if let responseData = data {
				completion(responseData)
			} else if let error = error {
				self.adyenResult = error.localizedDescription
				self.sendResult()
			} else {
				self.adyenResult = "Failed to create session."
				self.sendResult()
			}
		}.resume()
	}

	func checkoutViewController(_ controller: CheckoutViewController,
			requiresReturnURL completion: @escaping URLCompletion) {
		urlCompletion = completion
	}

	func checkoutViewController(_ controller: CheckoutViewController,
			didFinishWith result: PaymentRequestResult) {
		controller.presentingViewController?.dismiss(animated: true, completion: {
			self.checkoutResult(result: result)
		})
	}

	func checkoutResult(result: PaymentRequestResult) {
		switch result {
			case let .payment(payment):
				switch payment.status {
					case .authorised:
						self.verifyPayment(payment: payment)
					default:
						self.adyenResult = payment.status.rawValue.capitalized
						self.sendResult()
				}
			case let .error(error):
				self.adyenResult = error.errorDescription!
				self.sendResult()
		}
	}
	
	func verifyPayment(payment: Payment) {
		self.adyenPayload = payment.payload
		self.adyenResult = payment.status.rawValue.capitalized
		
		let url = URL(string: verifyURL)!
		var request = URLRequest(url: url)
		
		request.httpMethod = "POST"
		verifyDict["payload"] = adyenPayload
		request.httpBody = try? JSONSerialization.data(withJSONObject: verifyDict, options: [])
		
		request.allHTTPHeaderFields = [
			"Content-Type": "application/json"
		]
		
		let session = URLSession(configuration: .default)
		session.dataTask(with: request) { data, response, error in
			if let responseData = data {
				let responseJson = try? JSONSerialization.jsonObject(with: responseData, options: [])
				let responseDict = (responseJson as? [String : Any])!
				let authResponse = responseDict["authResponse"] as? String
				
				if (authResponse == payment.status.rawValue.capitalized) {
					self.sendResult()
				} else {
					self.adyenResult = "Failed to verify payment."
					self.sendResult()
				}
			} else if let error = error {
				self.adyenResult = error.localizedDescription
				self.sendResult()
			} else {
				self.adyenResult = "Failed to verify payment."
				self.sendResult()
			}
		}.resume()
	}
	
	func sendResult() {
		var dict = Dictionary<String, String>()
		dict["adyenResult"] = adyenResult
		dict["adyenPayload"] = adyenPayload
		sendEvent(withName: "onCheckoutDone", body: dict)
	}
}
