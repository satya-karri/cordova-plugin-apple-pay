import Foundation
import PassKit

@objc(ApplePay) class ApplePay : CDVPlugin, PKPaymentAuthorizationViewControllerDelegate {
    var paymentCallbackId : String?
    var successfulPayment = false
    
    /**
     * Check device for ApplePay capability
     */
    @objc(canMakePayments:) func canMakePayments(command: CDVInvokedUrlCommand){
        let callbackID = command.callbackId;
        
        do {
            let supportedNetworks = try getFromRequest(fromArguments: command.arguments, key: "supportedNetworks") as! Array
            let merchantCapabilities = try getFromRequest(fromArguments: command.arguments, key: "merchantCapabilities") as! Array

            let canMakePayments = PKPaymentAuthorizationViewController.canMakePayments(supportedNetworks, merchantCapabilities)

            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: canMakePayments)
            commandDelegate.send(result, callbackId: callbackID)
        } catch ValidationError.missingArgument(let message) {
            failWithError(message)
        } catch {
            failWithError(error.localizedDescription)
        }
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
            let merchantCapabilities = try getFromRequest(fromArguments: command.arguments, key: "merchantCapabilities") as! Array
            let requiredBillingContactFields = try getFromRequest(fromArguments: command.arguments, key: "requiredBillingContactFields") as! Array
            let requiredShippingContactFields = try getFromRequest(fromArguments: command.arguments, key: "requiredShippingContactFields") as! Array
            let supportedNetworks = try getFromRequest(fromArguments: command.arguments, key: "supportedNetworks") as! Array
            let totalLabel = try getFromRequest(fromArguments: command.arguments, key: "totalLabel") as! String
            let totalAmount = try getFromRequest(fromArguments: command.arguments, key: "totalAmount") as! NSNumber
            
            let request = PKPaymentRequest()
            request.merchantIdentifier = merchantId
            request.supportedNetworks = supportedNetworks
            request.merchantCapabilities = merchantCapabilities
            request.countryCode = countryCode
            request.currencyCode = currencyCode
            request.requiredBillingContactFields = requiredBillingContactFields
            request.requiredShippingContactFields = requiredShippingContactFields
            
            let nsamount = NSDecimalNumber(decimal: totalAmount.decimalValue);
            
            request.paymentSummaryItems = [PKPaymentSummaryItem(label: totalLabel, amount: nsamount)]
            
            if let c = PKPaymentAuthorizationViewController(paymentRequest: request) {
                c.delegate = self
                viewController.present(c, animated: true)
            }
        } catch ValidationError.missingArgument(let message) {
            failWithError(message)
        } catch {
            failWithError(error.localizedDescription)
        }
        
        
    }
    
    private func failWithError(_ error: String){
        let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error)
        commandDelegate.send(result, callbackId: paymentCallbackId)
    }
    
    private func getFromRequest(fromArguments arguments: [Any]?, key: String) throws -> Any {
        let val = (arguments?[0] as? [AnyHashable : Any])?[key]
        
        if val == nil {
            throw ValidationError.missingArgument("\(key) is required")
        }
        
        return val!
    }
    
    /**
     * Delegate methods
     */
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        completion(PKPaymentAuthorizationResult(status: PKPaymentAuthorizationStatus.success, errors: nil))
        successfulPayment = true
        let applePaymentString = String(data: payment.token.paymentData, encoding: .utf8)
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: applePaymentString)
        
        commandDelegate.send(result, callbackId: paymentCallbackId)
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        if !successfulPayment {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Payment cancelled")
            commandDelegate.send(result, callbackId: paymentCallbackId)
        }
            
        controller.dismiss(animated: true, completion: nil)
    }
}

enum ValidationError : Error {
    case missingArgument(String)
}
