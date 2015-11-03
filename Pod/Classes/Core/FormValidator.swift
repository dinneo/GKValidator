//
//  FormValidator.swift
//  EruValidator
//
//  Created by Göksel Köksal on 28/06/15.
//  Copyright © 2015 Eru. All rights reserved.
//

import Foundation

public protocol FormValidatorDelegate {
    
    func formValidator(formValidator: FormValidator, didChangeState state: ValidationState)
    func formValidator(formValidator: FormValidator, didValidateForType type: ValidationType, resultPairs: [ObjectValidationResultPair])
}

public class FormValidator : NSObject {
    
    public var delegate: FormValidatorDelegate?
    public var validationRuleSets: [ValidationType: GenericValidationRuleSet] = [ValidationType: GenericValidationRuleSet]()
    
    public private(set) var state: ValidationState = [] {
        didSet {
            
            if oldValue.rawValue == state.rawValue {
                return
            }
            
            if state.contains(ValidationState.Submittable) && !state.contains(ValidationState.Eligible) {
                state.remove(ValidationState.Submittable)
                
            }
            
            delegate?.formValidator(self, didChangeState: state)
        }
    }
    
    // TODO: Swift 2.0 currently does not support type covariance. Update String to AnyObject to support different types.
    public var fieldValidationDelegates: [FieldValidationDelegate<String>]? {
        didSet {
            if let fieldDelegates = fieldValidationDelegates {
                
                NSNotificationCenter.defaultCenter().removeObserver(self,
                    name: FieldDidChangeNotification,
                    object: nil)
                
                for fieldDelegate in fieldDelegates {
                    NSNotificationCenter.defaultCenter().addObserver(self,
                        selector: Selector("fieldDidChange:"),
                        name: FieldDidChangeNotification,
                        object: fieldDelegate)
                }
            }
        }
    }
    
    // MARK: Public methods
    
    public func validatorForField(field: AnyObject?) -> FieldValidator<String>? {
        
        if let fieldValidationDelegates = fieldValidationDelegates {
            for fieldDelegate in fieldValidationDelegates {
                if field === fieldDelegate.field {
                    return fieldDelegate.validator
                }
            }
        }
        
        return nil
    }
    
    public func addValidationRules(rules: [GenericValidationRule], forType type: ValidationType) {
        
        if let ruleSet = validationRuleSets[type] {
            ruleSet.rules.appendContentsOf(rules)
        }
        else {
            validationRuleSets[type] = GenericValidationRuleSet(rules: rules)
        }
    }
    
    public func validateForType(type: ValidationType) -> [ObjectValidationResultPair] {
        
        guard let fieldDelegates = fieldValidationDelegates
            where (type == ValidationType.Submission ? state.contains(ValidationState.Eligible) : true) else {
            return []
        }
        
        var resultPairs = [ObjectValidationResultPair]()
        var success = true
        
        // Validate field rules.
        
        for fieldDelegate in fieldDelegates {
            
            if let field = fieldDelegate.field {
                
                let result = fieldDelegate.validateForType(type)
                
                if success {
                    success = result.isSuccess
                }
                
                resultPairs.append((object: field, result: result));
            }
        }
            
        // Validate form rules.
            
        if let ruleSet = validationRuleSets[type] where success {
            
            let result = ruleSet.validate()
            success = result.isSuccess
            resultPairs.append((object: self, result: result))
        }
        
        // Determine state and return.
        
        let formState = affectedStateForValidationType(type)
        
        if success {
            state.insert(formState)
        }
        else {
            state.remove(formState)
        }
        
        delegate?.formValidator(self, didValidateForType: type, resultPairs: resultPairs)
        return resultPairs
    }
    
    public func fieldDidChange(notification: NSNotification) {
        
        validateForType(ValidationType.Eligibility)
    }
}
