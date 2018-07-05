import Foundation
import Adyen

@objc(ReAdyenPay)
class ReAdyenPay: NSObject, CheckoutViewControllerDelegate {
	var bridge: RCTBridge!
	
	var checkoutData = Dictionary<String, Any>()
	var checkoutURL = String()
	var checkoutAPIKeyName = String()
	var checkoutAPIKeyValue = String()
	
	fileprivate var urlCompletion: URLCompletion?
	
	@objc(applicationDidOpenURL:)
	func applicationDidOpen(_ url: URL) {
		urlCompletion?(url)
	}
	
	@objc
	func sendEvent(_ eventName: String, params: Dictionary<String, Any>) {
		self.bridge.eventDispatcher().sendAppEvent(withName: eventName, body: params)
	}
	
	@objc
	func beginPayment() {
		let checkoutViewController = CheckoutViewController(delegate: self)
		
		DispatchQueue.main.async {
			let appDelegate = UIApplication.shared.delegate as! AppDelegate
			let rootViewController = appDelegate.window.rootViewController
			
			rootViewController?.present(checkoutViewController, animated: true)
		}
	}
	
	func checkoutViewController(_ controller: CheckoutViewController,
			requiresPaymentDataForToken token: String,
			completion: @escaping DataCompletion) {
		var paymentDetails: [String: Any] = checkoutData
		paymentDetails["token"] = token
		
		let url = URL(string: checkoutURL)!
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = try? JSONSerialization.data(withJSONObject: paymentDetails, options: [])
		
		request.allHTTPHeaderFields = [
			checkoutAPIKeyName: checkoutAPIKeyValue,
			"Content-Type": "application/json"
		]
		
		let session = URLSession(configuration: .default)
		session.dataTask(with: request) { data, response, error in
			if let error = error {
				var dict = Dictionary<String, String>()
				dict["adyenResult"] = error.localizedDescription
				self.sendEvent("onCheckoutDone", params: dict)
			} else if let data = data {
				completion(data)
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
			self.paymentManagerResult(result: result)
		})
	}
	
	func paymentManagerResult(result: PaymentRequestResult) {
		var adyenResult = String()
		var adyenToken = String()
		
		switch result {
			case let .payment(payment):
				switch payment.status {
					case .received:
						adyenResult = "PAYMENT_RECEIVED"
					case .authorised:
						adyenResult = "PAYMENT_AUTHORISED"
					case .refused:
						adyenResult = "PAYMENT_REFUSED"
					case .cancelled:
						adyenResult = "PAYMENT_CANCELLED"
					case .error:
						adyenResult = "PAYMENT_ERROR"
				}
				
				adyenToken = payment.payload
			
			case let .error(error):
				adyenResult = error.errorDescription!
		}
		
		if (adyenResult == "PAYMENT_RECEIVED" || adyenResult == "PAYMENT_AUTHORISED") {
			var dict = Dictionary<String, String>()
			dict["adyenResult"] = adyenResult
			dict["adyenToken"] = adyenToken
			sendEvent("onCheckoutDone", params: dict)
		} else {
			var dict = Dictionary<String, String>()
			dict["adyenResult"] = adyenResult
			sendEvent("onCheckoutDone", params: dict)
		}
	}
	
	@objc(showCheckout:)
	func showCheckout(checkoutDict: NSDictionary) {
		checkoutData = checkoutDict as! [String : Any]
		checkoutURL = (checkoutDict["checkoutURL"] as? String)!
		checkoutAPIKeyName = (checkoutDict["checkoutAPIKeyName"] as? String)!
		checkoutAPIKeyValue = (checkoutDict["checkoutAPIKeyValue"] as? String)!
		
		checkoutData.removeValue(forKey: "checkoutURL")
		checkoutData.removeValue(forKey: "checkoutAPIKeyName")
		checkoutData.removeValue(forKey: "checkoutAPIKeyValue")
		
		beginPayment()
	}
}