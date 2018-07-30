import Foundation
import Adyen

@objc(ReAdyenPay)
class ReAdyenPay: RCTEventEmitter, CheckoutViewControllerDelegate {
	override func supportedEvents() -> [String]! {
		return ["onCheckoutDone", "url"]
	}

	fileprivate var checkoutDict = Dictionary<String, Any>()
	fileprivate var checkoutURL = String()
	fileprivate var checkoutAPIKeyName = String()
	fileprivate var checkoutAPIKeyValue = String()
	fileprivate var urlCompletion: URLCompletion?

	@objc(applicationRedirect:)
	func applicationRedirect(_ url: URL) {
		urlCompletion?(url)
	}

	@objc(showCheckout:)
	func showCheckout(_ checkoutNSDict: NSDictionary) {
		checkoutDict = checkoutNSDict as! [String : Any]
		checkoutURL = (checkoutNSDict["checkoutURL"] as? String)!

		checkoutDict.removeValue(forKey: "checkoutURL")

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
		var adyenPayload = String()

		switch result {
			case let .payment(payment):
				adyenResult = payment.status.rawValue.capitalized
				adyenPayload = payment.payload
				var dict = Dictionary<String, String>()
				dict["adyenResult"] = adyenResult
				dict["adyenPayload"] = adyenPayload
				sendEvent(withName: "onCheckoutDone", body: dict)

			case let .error(error):
				adyenResult = error.errorDescription!
				var dict = Dictionary<String, String>()
				dict["adyenResult"] = adyenResult
				sendEvent(withName: "onCheckoutDone", body: dict)
		}
	}
}
