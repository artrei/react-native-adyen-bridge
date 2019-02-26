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
	private JSONObject checkoutObject;
	private JSONObject verifyObject;
	private String checkoutUrl;
	private String verifyUrl;
	private String checkoutAPIKeyName;
	private String checkoutAPIKeyValue;
	private String adyenPayload;
	private String adyenResult;
	private PaymentRequest paymentRequest;

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

		if (!checkoutObject.isNull("checkoutURL")) {
			checkoutUrl = data.getString("checkoutURL");
			checkoutObject.remove("checkoutURL");
		}

		if (!checkoutObject.isNull("verifyURL")) {
			verifyUrl = data.getString("verifyURL");
			checkoutObject.remove("verifyURL");
		}
		
		if (!checkoutObject.isNull("checkoutAPIKeyName")) {
			checkoutAPIKeyName = data.getString("checkoutAPIKeyName");
			checkoutObject.remove("checkoutAPIKeyName");
		}
		
		if (!checkoutObject.isNull("checkoutAPIKeyValue")) {
			checkoutAPIKeyValue = data.getString("checkoutAPIKeyValue");
			checkoutObject.remove("checkoutAPIKeyValue");
		}

		try {
			checkoutObject.put("amount", new JSONObject(data.getMap("amount").toHashMap()));
		} catch(JSONException e) {}

		paymentRequest = new PaymentRequest(this.getCurrentActivity(), paymentRequestListener);
		paymentRequest.start();
	}

	private final PaymentRequestListener paymentRequestListener = new PaymentRequestListener() {
		@Override
		public void onPaymentDataRequested(final PaymentRequest paymentRequest, String token,
				final PaymentDataCallback paymentDataCallback) {
			final Map<String, String> headers = new HashMap<>();
			headers.put("Content-Type", "application/json; charset=UTF-8");

			if (checkoutAPIKeyName != null && checkoutAPIKeyValue != null) {
				headers.put(checkoutAPIKeyName, checkoutAPIKeyValue);
			}

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
					adyenResult = e.getMessage();
					sendResult();
					paymentRequest.cancel();
				}
			});
		}

		@Override
		public void onPaymentResult(PaymentRequest paymentRequest, PaymentRequestResult paymentRequestResult) {
			if (paymentRequestResult.isProcessed()) {
				if (paymentRequestResult.getPayment().getPaymentStatus() == Payment.PaymentStatus.AUTHORISED) {
					verifyPayment(paymentRequestResult.getPayment());
				} else {
					adyenResult = paymentRequestResult.getPayment().getPaymentStatus().toString();
					sendResult();
				}
			} else {
				Throwable error = paymentRequestResult.getError();
				adyenResult = error.getMessage();
				sendResult();
			}
		}
	};

	private void verifyPayment(final Payment payment) {
		adyenPayload = payment.getPayload();
		adyenResult = payment.getPaymentStatus().toString();

		final Map<String, String> headers = new HashMap<>();
		headers.put("Content-Type", "application/json; charset=UTF-8");

		verifyObject = new JSONObject();

		try {
			verifyObject.put("payload", adyenPayload);
		} catch(Exception e) {}

		AsyncHttpClient.post(verifyUrl, headers, verifyObject.toString(), new HttpResponseCallback() {
			@Override
			public void onSuccess(final byte[] response) {
				try {
					JSONObject jsonVerifyResponse = new JSONObject(new String(response, Charset.forName("UTF-8")));
					String authResponse = jsonVerifyResponse.getString("authResponse");
					if (authResponse.equalsIgnoreCase(adyenResult)) {
						sendResult();
					} else {
						adyenResult = "Failed to verify payment.";
						sendResult();
					}
				} catch (JSONException e) {
					adyenResult = e.getMessage();
					sendResult();
				}
			}
			@Override
			public void onFailure(final Throwable e) {
				adyenResult = e.getMessage();
				sendResult();
			}
		});
	}

	private void sendResult() {
		WritableMap map = Arguments.createMap();
		map.putString("adyenResult", adyenResult);
		map.putString("adyenPayload", adyenPayload);
		sendEvent("onCheckoutDone", map);
	}
}