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

public class ReAdyenModule extends ReactContextBaseJavaModule {
	private String checkoutUrl = "";
	private String checkoutAPIKeyName = "";
	private String checkoutAPIKeyValue = "";
	private PaymentRequest paymentRequest;
	private JSONObject checkoutObject;

	public ReAdyenModule(ReactApplicationContext reactContext) {
		super(reactContext);
	}

	@Override
	public String getName() {
		return "ReAdyenPay";
	}

	private void sendEvent(String eventName, WritableMap params) {
		getReactApplicationContext()
				.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
				.emit(eventName, params);
	}

	@ReactMethod
	public void showCheckout(ReadableMap data) {
		checkoutObject = new JSONObject(data.toHashMap());
		checkoutUrl = data.getString("checkoutURL");
		checkoutAPIKeyName = data.getString("checkoutAPIKeyName");
		checkoutAPIKeyValue = data.getString("checkoutAPIKeyValue");

		try {
			checkoutObject.put("amount", new JSONObject(data.getMap("amount").toHashMap()));
		} catch(JSONException e) {}

		checkoutObject.remove("checkoutURL");
		checkoutObject.remove("checkoutAPIKeyName");
		checkoutObject.remove("checkoutAPIKeyValue");

		paymentRequest = new PaymentRequest(this.getCurrentActivity(), paymentRequestListener);
		paymentRequest.start();
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
					map.putString("adyenResult", e.getMessage());
					sendEvent("onCheckoutDone", map);
					paymentRequest.cancel();
				}
			});
		}

		@Override
		public void onPaymentResult(PaymentRequest paymentRequest, PaymentRequestResult paymentRequestResult) {
			String adyenResult = "";
			String adyenToken = "";
			
			if (paymentRequestResult.isProcessed()) {
				Payment payment = paymentRequestResult.getPayment();
				WritableMap map = Arguments.createMap();
				adyenResult = payment.getPaymentStatus().toString();
				adyenToken = payment.getPayload();
				map.putString("adyenResult", adyenResult);
				map.putString("adyenToken", adyenToken);
				sendEvent("onCheckoutDone", map);
			} else {
				Throwable error = paymentRequestResult.getError();
				WritableMap map = Arguments.createMap();
				map.putString("adyenResult", error.getMessage());
				sendEvent("onCheckoutDone", map);
			}
		}
	};
}