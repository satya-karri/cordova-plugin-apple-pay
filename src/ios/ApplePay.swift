import Foundation
import PassKit

@available(iOS 11.0, *)
@objc(ApplePay) class ApplePay : CDVPlugin, PKPaymentAuthorizationViewControllerDelegate {
    var paymentCallbackId : String?
    var successfulPayment: Bool = false;
    var paymentAuthorizationBlock : ((PKPaymentAuthorizationResult) -> Void)? = nil;
    
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
    
    /**
    * Update payment sheet status after processing the payment
    **/
    @objc(updatePaymentStatus:) func updatePaymentStatus(command: CDVInvokedUrlCommand){
        let callbackId = command.callbackId;
        do {
            successfulPayment = try getFromRequest(fromArguments: command.arguments, key: "success") as! Bool;
            if ((self.paymentAuthorizationBlock) != nil) {
                if (successfulPayment) {
                    self.paymentAuthorizationBlock!(PKPaymentAuthorizationResult(status: PKPaymentAuthorizationStatus.success, errors: nil));
                } else {
                    self.paymentAuthorizationBlock!(PKPaymentAuthorizationResult(status: PKPaymentAuthorizationStatus.failure, errors: nil));
                }
                let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
                commandDelegate.send(result, callbackId: callbackId)
            } else {
                failWithError("could not update payment status", id: callbackId!)
            }
        } catch ValidationError.missingArgument(let message) {
            failWithError(message, id: callbackId!)
        } catch {
           failWithError(error.localizedDescription, id: callbackId!)
        }
    }
    
    /**
     * Request payment token
     */
    @objc(makePaymentRequest: ) func makePaymentRequest(command: CDVInvokedUrlCommand){
        self.paymentCallbackId = command.callbackId;
        
        self.paymentAuthorizationBlock = nil;
        
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

            request.requiredBillingContactFields = getContactFields(fromArguments: command.arguments, key: "requiredBillingContactFields");
            request.requiredShippingContactFields = getContactFields(fromArguments: command.arguments, key: "requiredShippingContactFields");

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
    
    private func getContactFields(fromArguments arguments: [Any]?, key: String) -> Set<PKContactField> {
        var contactFieldSet = Set<PKContactField>();
        do {
            let contactFields = try getFromRequest(fromArguments: arguments, key: key) as! Array<String>;
            for contactField in contactFields {
                switch contactField {
                    case "postalAddress":
                        contactFieldSet.insert(PKContactField.postalAddress);
                        break;
                    case "phoneticName":
                        contactFieldSet.insert(PKContactField.phoneticName);
                        break;
                    case "email":
                        contactFieldSet.insert(PKContactField.emailAddress);
                        break;
                    case "phone":
                        contactFieldSet.insert(PKContactField.phoneNumber);
                        break;
                    case "name":
                        contactFieldSet.insert(PKContactField.name);
                        break;
                    default:
                        contactFieldSet.insert(PKContactField.name);
                        break;
                }
            }
        } catch {
            // do nothing
        }
        return contactFieldSet;
    }
    
    private func getSupportedNetworks(fromArguments arguments: [Any]?) throws -> Array<PKPaymentNetwork> {
        let supportedNetworksArray = try getFromRequest(fromArguments: arguments, key: "supportedNetworks") as! Array<String>;
        let supportedNetworks = supportedNetworksArray.map { (network) -> PKPaymentNetwork in
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

        self.paymentAuthorizationBlock = completion;

        var token = PaymentToken();
        token.transactionIdentifier = payment.token.transactionIdentifier;
        
        var paymentMethod = PaymentMethod();
        paymentMethod.network = payment.token.paymentMethod.network?.rawValue;
        paymentMethod.displayName = payment.token.paymentMethod.displayName;
        paymentMethod.type = payment.token.paymentMethod.type.rawValue;
        token.paymentMethod = paymentMethod;
        
        token.paymentData = String(data: payment.token.paymentData, encoding: .utf8);
        
        let asas = String(data: payment.token.paymentData, encoding: .utf8);
        
        var applePayData = ApplePayData();
        applePayData.billingContact = getContactObject(fromPKContact: payment.billingContact);
        applePayData.shippingContact = getContactObject(fromPKContact: payment.shippingContact);
        applePayData.token = token;
        
        let jsonData = try! JSONEncoder().encode(applePayData)
        let applePaymentData = String(data: jsonData, encoding: .utf8);
        
        let resultArray = [applePaymentData,  asas];
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: resultArray as [Any])
        commandDelegate.send(result, callbackId: paymentCallbackId);
        
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true, completion: nil);

        if (!successfulPayment) {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Payment cancelled")
            commandDelegate.send(result, callbackId: paymentCallbackId)
        }
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
