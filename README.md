# Cordova Apple Pay integration
This plugin is built as unified method for obtaining payment tokens to forward it to payment processor (eg Adyen,
Stripe, Wayforpay, Liqpay etc).

## Installation

For iOS, you have to have valid developer account with merchant set up and ApplePay capability and a merchant id
configured in your Xcode project. Merchant id can be obtained
from https://developer.apple.com/account/resources/identifiers/list/merchant. Do configuration manually or using
config.xml:

```
<platform name="ios">
  <config-file target="*-Debug.plist" parent="com.apple.developer.in-app-payments">
    <array>
      <string>developer merchant ID here</string>
    </array>
  </config-file>

  <config-file target="*-Release.plist" parent="com.apple.developer.in-app-payments">
    <array>
      <string>production merchant ID here</string>
    </array>
  </config-file>
</platform>
```

## Usage

`canMakePayments()` checks whether device is capable to make payments via Apple Pay.

```
let request = {
  "supportedNetworks": [
    "visa",
    "masterCard",
    "amex",
    "discover"
  ],
  "merchantCapabilities": [
    "supports3DS"
  ]
}

ApplePay.canMakePayments(request).then(successCallback).catch(errorCallback);
```

`makePaymentRequest()` initiates pay session.

```
let request = {
  "supportedNetworks": [
    "visa",
    "masterCard",
    "amex",
    "discover"
  ],
  "merchantCapabilities": [
    "supports3DS"
  ],
  "merchantId": "",
  "currencyCode": "",
  "countryCode": "",
  "requiredBillingContactFields": [
    "name",
    "postalAddress"
  ],
  "requiredShippingContactFields": [
    "name",
    "postalAddress"
  ],
  "totalLabel": "",
  "totalAmount": 
}

var successCallback = function (data) {
  var applePayData = data[0];
  var tokenPaymentData = data[1];
  var paymentData = JSON.parse(applePayData);
  paymentData.token.paymentData = JSON.parse(tokenPaymentData);

  // send the paymentdata object to the backend
}
ApplePay.makePaymentRequest(request).then(successCallback).catch(errorCallback);
```

All parameters in request object are required except requiredShippingContactFields and requiredBillingContactFields.



`updatePaymentStatus()` updates the payment sheet if the payment has been successfully processed.

```
let request = {
  "success": true,
}
ApplePay.updatePaymentStatus(request);

```
