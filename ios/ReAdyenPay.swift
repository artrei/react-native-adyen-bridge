import Foundation
import Adyen

@objc(ReAdyenPay)
class ReAdyenPay: RCTEventEmitter, CheckoutViewControllerDelegate {
	fileprivate var checkoutDict = Dictionary<String, Any>()
	fileprivate var checkoutURL = String()
	fileprivate var checkoutAPIKeyName = String()
	fileprivate var checkoutAPIKeyValue = String()
	fileprivate var urlCompletion: URLCompletion?

	@objc(applicationDidOpenURL:)
	func applicationDidOpen(_ url: URL) {
		urlCompletion?(url)
	}

	override func supportedEvents() -> [String]! {
		return ["onCheckoutDone"]
	}

	@objc(showCheckout:)
	func showCheckout(checkoutNSDict: NSDictionary) {
		checkoutDict = checkoutNSDict as! [String : Any]
		checkoutURL = (checkoutNSDict["checkoutURL"] as? String)!
		checkoutAPIKeyName = (checkoutNSDict["checkoutAPIKeyName"] as? String)!
		checkoutAPIKeyValue = (checkoutNSDict["checkoutAPIKeyValue"] as? String)!

		checkoutDict.removeValue(forKey: "checkoutURL")
		checkoutDict.removeValue(forKey: "checkoutAPIKeyName")
		checkoutDict.removeValue(forKey: "checkoutAPIKeyValue")

		startCheckout()
	}

	func startCheckout() {
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
		let url = URL(string: checkoutURL)!
		var request = URLRequest(url: url)

		request.httpMethod = "POST"
		checkoutDict["token"] = token
		request.httpBody = try? JSONSerialization.data(withJSONObject: checkoutDict, options: [])

		request.allHTTPHeaderFields = [
			checkoutAPIKeyName: checkoutAPIKeyValue,
			"Content-Type": "application/json"
		]

		let session = URLSession(configuration: .default)
		session.dataTask(with: request) { data, response, error in
			if let error = error {
				var dict = Dictionary<String, String>()
				dict["adyenResult"] = error.localizedDescription
				self.sendEvent(withName: "onCheckoutDone", body: dict)
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
			self.checkoutResult(result: result)
		})
	}

	func checkoutResult(result: PaymentRequestResult) {
		var adyenResult = String()
		var adyenToken = String()

		switch result {
			case let .payment(payment):
				adyenResult = payment.status.rawValue.capitalized
				adyenToken = payment.payload
				var dict = Dictionary<String, String>()
				dict["adyenResult"] = adyenResult
				dict["adyenToken"] = adyenToken
				sendEvent(withName: "onCheckoutDone", body: dict)

			case let .error(error):
				adyenResult = error.errorDescription!
				var dict = Dictionary<String, String>()
				dict["adyenResult"] = adyenResult
				sendEvent(withName: "onCheckoutDone", body: dict)
		}
	}
}
