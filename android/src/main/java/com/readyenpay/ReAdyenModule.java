package com.readyenpay;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import com.adyen.core.PaymentRequest;
import com.adyen.core.interfaces.HttpResponseCallback;
import com.adyen.core.interfaces.PaymentDataCallback;
import com.adyen.core.interfaces.PaymentRequestListener;
import com.adyen.core.models.Payment;
import com.adyen.core.models.PaymentRequestResult;
import com.adyen.core.utils.AsyncHttpClient;

import org.json.JSONException;
import org.json.JSONObject;

import java.nio.charset.Charset;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

import java.util.ArrayList;
import java.io.StringWriter;
import java.io.PrintWriter;

public class ReAdyenModule extends ReactContextBaseJavaModule {
	private String checkoutUrl = "";
	private String checkoutAPIKeyName = "";
	private String checkoutAPIKeyValue = "";
	private PaymentRequest paymentRequest;
	private JSONObject checkoutObject;

	public ReAdyenModule(ReactApplicationContext reactContext) {
		super(reactContext);
	}

	private final PaymentRequestListener paymentRequestListener = new PaymentRequestListener() {
		@Override
		public void onPaymentDataRequested(final PaymentRequest paymentRequest, String token,
				final PaymentDataCallback paymentDataCallback) {
			final Map<String, String> headers = new HashMap<>();
			headers.put("Content-Type", "application/json; charset=UTF-8");
			headers.put(checkoutAPIKeyName, checkoutAPIKeyValue);

			try {
				checkoutObject.put("token", token);
			} catch(Exception e) {}

			AsyncHttpClient.post(checkoutUrl, headers, checkoutObject.toString(), new HttpResponseCallback() {
				@Override
				public void onSuccess(final byte[] response) {
					paymentDataCallback.completionWithPaymentData(response);
				}
				@Override
				public void onFailure(final Throwable e) {
					WritableMap map = Arguments.createMap();
					StringWriter sw = new StringWriter();
					e.printStackTrace(new PrintWriter(sw));
					map.putString("adyenResult", "Current stack trace is:\n" + sw.toString());
					sendEvent("onCheckoutDone", map);
					paymentRequest.cancel();
				}
			});
		}

		@Override
		public void onPaymentResult(PaymentRequest paymentRequest, PaymentRequestResult paymentRequestResult) {
			Payment payment = paymentRequestResult.getPayment();
			String adyenResult = "";
			
			if (paymentRequestResult.isProcessed()) {
				// convert status:
				switch (payment.getPaymentStatus()) {
					case RECEIVED:
						adyenResult = "PAYMENT_RECEIVED";
						break;
					case AUTHORISED:
						adyenResult = "PAYMENT_AUTHORISED";
						break;
					case REFUSED:
						adyenResult = "PAYMENT_REFUSED";
						break;
					case CANCELLED:
						adyenResult = "PAYMENT_CANCELLED";
						break;
					case ERROR:
						adyenResult = String.format("Payment failed with error (%s)", payment.getPayload());
						break;
				}
			}

			if (adyenResult == "PAYMENT_RECEIVED" || adyenResult == "PAYMENT_AUTHORISED") {
				WritableMap map = Arguments.createMap();
				map.putString("adyenResult", adyenResult);
				map.putString("adyenToken", payment.getPayload());
				sendEvent("onCheckoutDone", map);
			} else {
				WritableMap map = Arguments.createMap();
				map.putString("adyenResult", adyenResult);
				sendEvent("onCheckoutDone", map);
			}
		}
	};

	private static ArrayList<ReAdyenModule> modules = new ArrayList<>();

	@Override
	public String getName() {
		return "ReAdyenPay";
	}

	@Override
	public void initialize() {
		super.initialize();
		modules.add(this);
	}

	@Override
	public void onCatalystInstanceDestroy() {
		super.onCatalystInstanceDestroy();
		modules.remove(this);
	}

	private void sendEvent(String eventName, WritableMap params) {
		getReactApplicationContext()
				.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
				.emit(eventName, params);
	}

	@ReactMethod
	public void showCheckout(ReadableMap data) {
		checkoutObject = new JSONObject(data.toHashMap());

		try {
			checkoutObject.put("amount", new JSONObject(data.getMap("amount").toHashMap()));
		} catch(JSONException e) {}

		checkoutObject.remove("checkoutURL");
		checkoutObject.remove("checkoutAPIKeyName");
		checkoutObject.remove("checkoutAPIKeyValue");

		checkoutUrl = data.getString("checkoutURL");
		checkoutAPIKeyName = data.getString("checkoutAPIKeyName");
		checkoutAPIKeyValue = data.getString("checkoutAPIKeyValue");

		paymentRequest = new PaymentRequest(this.getCurrentActivity(), paymentRequestListener);
		paymentRequest.start();
	}
}