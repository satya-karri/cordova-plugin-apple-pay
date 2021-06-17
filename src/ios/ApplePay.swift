import Foundation
import PassKit

@available(iOS 11.0, *)
@objc(ApplePay) class ApplePay : CDVPlugin, PKPaymentAuthorizationViewControllerDelegate {
    var paymentCallbackId : String?
//    var completionHandler = nil;
    var successfulPayment = false
    
    /**
     * Check device for ApplePay capability
     */
    @objc(canMakePayments:) func canMakePayments(command: CDVInvokedUrlCommand){
        let callbackId = command.callbackId;
        
        do {
            let supportedNetworks = try getSupportedNetworks(fromArguments: command.arguments);
            let merchantCapability = try getMerchantCapability(fromArguments: command.arguments);

            let canMakePayments = PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: supportedNetworks, capabilities: merchantCapability);

            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: canMakePayments)
            commandDelegate.send(result, callbackId: callbackId)
        } catch ValidationError.missingArgument(let message) {
            failWithError(message, id: callbackId!)
        } catch {
            failWithError(error.localizedDescription, id: callbackId!)
        }
    }
    
    @objc(updatePaymentStatus:) func updatePaymentStatus(command: CDVInvokedUrlCommand){
//        let callbackId = command.callbackId;

        successfulPayment = (((command.arguments?[0] as? [AnyHashable : Bool])?["success"]) != nil);

//        if (successfulPayment) {
//            PKPaymentAuthorizationResult(status: PKPaymentAuthorizationStatus.success, errors: nil);
////            completionHandler(PKPaymentAuthorizationResult(status: PKPaymentAuthorizationStatus.success, errors: nil))
//        } else {
//            PKPaymentAuthorizationResult(status: PKPaymentAuthorizationStatus.failure, errors: nil)
////            completionHandler(PKPaymentAuthorizationResult(status: PKPaymentAuthorizationStatus.failure))
//        }
    }
    
    /**
     * Request payment token
     */
    @objc(makePaymentRequest: ) func makePaymentRequest(command: CDVInvokedUrlCommand){
        self.paymentCallbackId = command.callbackId;
        
        do {
            let countryCode = try getFromRequest(fromArguments: command.arguments, key: "countryCode") as! String
            let currencyCode = try getFromRequest(fromArguments: command.arguments, key: "currencyCode") as! String
            let merchantId = try getFromRequest(fromArguments: command.arguments, key: "merchantId") as! String
            
            
            let totalLabel = try getFromRequest(fromArguments: command.arguments, key: "totalLabel") as! String
            let totalAmount = try getFromRequest(fromArguments: command.arguments, key: "totalAmount") as! NSNumber
            
            let request = PKPaymentRequest()
            request.merchantIdentifier = merchantId
            request.supportedNetworks = try getSupportedNetworks(fromArguments: command.arguments);
            request.merchantCapabilities = try getMerchantCapability(fromArguments: command.arguments);
            request.countryCode = countryCode
            request.currencyCode = currencyCode

            let requiredBillingContactFields: Set = [PKContactField.name, PKContactField.postalAddress];
            let requiredShippingContactFields: Set = [PKContactField.emailAddress];
            request.requiredBillingContactFields = requiredBillingContactFields
            request.requiredShippingContactFields = requiredShippingContactFields

            let nsamount = NSDecimalNumber(decimal: totalAmount.decimalValue);
            
            request.paymentSummaryItems = [PKPaymentSummaryItem(label: totalLabel, amount: nsamount)];
            
            if let c = PKPaymentAuthorizationViewController(paymentRequest: request) {
                c.delegate = self
                viewController.present(c, animated: true)
            }
        } catch ValidationError.missingArgument(let message) {
            failWithError(message, id: paymentCallbackId!)
        } catch {
            failWithError(error.localizedDescription, id: paymentCallbackId!)
        }
        
        
    }
    
    private func failWithError(_ error: String, id callbackId: String){
        let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error)
        commandDelegate.send(result, callbackId: callbackId)
    }
    
    private func getFromRequest(fromArguments arguments: [Any]?, key: String) throws -> Any {
        let val = (arguments?[0] as? [AnyHashable : Any])?[key]
        
        if val == nil {
            throw ValidationError.missingArgument("\(key) is required")
        }
        
        return val!
    }
    
    private func getSupportedNetworks(fromArguments arguments: [Any]?) throws -> Array<PKPaymentNetwork> {
        print(arguments)
        let supportedNetworksasa = try getFromRequest(fromArguments: arguments, key: "supportedNetworks") as! Array<String>;
        print(supportedNetworksasa);
        let supportedNetworks = supportedNetworksasa.map { (network) -> PKPaymentNetwork in
            switch network {
                case "amex":
                    return PKPaymentNetwork.amex;
                case "visa":
                    return PKPaymentNetwork.visa;
                case "discover":
                    return PKPaymentNetwork.discover;
                case "mastercard":
                    return PKPaymentNetwork.amex;
                default:
                    return PKPaymentNetwork.masterCard
            }
        };
        return supportedNetworks;
    }
    
    private func getMerchantCapability(fromArguments arguments: [Any]?) throws -> PKMerchantCapability {
        let merchantCapabilities = try getFromRequest(fromArguments: arguments, key: "merchantCapabilities") as! Array<String>;
        
        print(merchantCapabilities);
    
        if (merchantCapabilities.count < 1) {
            return PKMerchantCapability.capability3DS;
        }
        
        switch merchantCapabilities[0] {
            case "supports3DS":
                return PKMerchantCapability.capability3DS;
            case "supportsEMV":
                return PKMerchantCapability.capabilityEMV;
            case "supportsCredit":
                return PKMerchantCapability.capabilityCredit;
            case "supportsDebit":
                return PKMerchantCapability.capabilityDebit;
            default:
                return PKMerchantCapability.capability3DS;
        }
    }

    private func getContactObject(fromPKContact contact: PKContact?) -> Contact {
        var newContact = Contact();
        newContact.phoneNumber = contact?.phoneNumber?.stringValue;
        newContact.emailAddress = contact?.emailAddress;
        newContact.givenName = contact?.name?.givenName;
        newContact.familyName = contact?.name?.familyName;
        newContact.phoneticGivenName = contact?.name?.phoneticRepresentation?.givenName;
        newContact.phoneticFamilyName = contact?.name?.phoneticRepresentation?.familyName;
        newContact.locality = contact?.postalAddress?.subLocality;
        
        newContact.locality = contact?.postalAddress?.city;
        newContact.subLocality = contact?.postalAddress?.subLocality;
        
        newContact.postalCode = contact?.postalAddress?.postalCode;
        
        newContact.administrativeArea = contact?.postalAddress?.state;
        newContact.subAdministrativeArea = contact?.postalAddress?.subAdministrativeArea;
        
        newContact.country = contact?.postalAddress?.country;
        newContact.countryCode = contact?.postalAddress?.isoCountryCode;

        return newContact;
    }
    
    /**
     * Delegate methods
     */
    
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {

//        completionHandler = completion;

        var token = PaymentToken();
        token.transactionIdentifier = payment.token.transactionIdentifier;
        
        var paymentMethod = PaymentMethod();
        paymentMethod.network = payment.token.paymentMethod.network?.rawValue;
        paymentMethod.displayName = payment.token.paymentMethod.displayName;
        paymentMethod.type = payment.token.paymentMethod.type.rawValue;
        token.paymentMethod = paymentMethod;
        
        token.paymentData = String(data: payment.token.paymentData, encoding: .utf8);
        
        var applePayData = ApplePayData();
        applePayData.billingContact = getContactObject(fromPKContact: payment.billingContact);
        applePayData.shippingContact = getContactObject(fromPKContact: payment.shippingContact);
        applePayData.token = token;

        let jsonData = try! JSONEncoder().encode(applePayData)
        let applePaymentData = String(data: jsonData, encoding: .utf8);
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: applePaymentData)
        commandDelegate.send(result, callbackId: paymentCallbackId);
        
        completion(PKPaymentAuthorizationResult(status: PKPaymentAuthorizationStatus.success, errors: nil))
        successfulPayment = true
        
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        print("paymentAuthorizationViewControllerDidFinish");
        if (!successfulPayment) {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Payment cancelled")
            commandDelegate.send(result, callbackId: paymentCallbackId)
        }
        controller.dismiss(animated: true, completion: nil);
    }
}

enum ValidationError : Error {
    case missingArgument(String)
}

struct Contact: Codable {
    var phoneNumber: String?
    var emailAddress: String?
    var givenName: String?
    var familyName: String?
    var phoneticGivenName: String?
    var phoneticFamilyName: String?
    var subLocality: String?
    var locality: String?
    var postalCode: String?
    var subAdministrativeArea: String?
    var administrativeArea: String?
    var country: String?
    var countryCode: String?
}

struct PaymentToken: Codable {
    var paymentMethod: PaymentMethod?
    var transactionIdentifier: String?
    var paymentData: String?
}

struct PaymentMethod: Codable {
    var displayName: String?
    var network: String?
    var type: UInt?
}

struct ApplePayData: Codable {
    var billingContact: Contact?
    var shippingContact: Contact?
    var token: PaymentToken?
}
