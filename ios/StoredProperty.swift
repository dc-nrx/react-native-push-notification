//
//  StoredProperty.swift
//
//
//  Created by Dmytro Chapovskyi on 07.12.2019.
//  Copyright © 2019 Dmytro Chapovskyi. All rights reserved.
//

import Foundation

class StoredProperty<T> {
	
	let key: String
	let userDefaults: UserDefaults
	
	//MARK:- Public Members
	var value: T? {
		set {
			cache = newValue
			userDefaults.set(newValue, forKey: key)
			userDefaults.synchronize()
		}
		get {
			if cache == nil {
				cache = userDefaults.value(forKey: key) as! T?
			}
			return cache
		}
	}
	
	//MARK:- Private Members
	private var cache: T?

	init(key: String, userDefaults: UserDefaults = UserDefaults.standard) {
		self.key = key
		self.userDefaults = userDefaults
	}
	
}
