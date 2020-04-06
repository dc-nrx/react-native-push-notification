//
//  BackgroundLocationTracker.swift
//
//
//  Created by Dmytro Chapovskyi on 28.03.2020.
//  Copyright © 2020 Dmytro Chapovskyi. All rights reserved.
//

import Foundation
import CoreLocation

/**
The class is intended for tracking significant location changes (including situations when the app is killed) and sending an update request to the backend (see `actionMinInterval`, `url` and `httpHeader` for configuration details).
To use it just call `BackgroundLocationTracker.shared.start(...)` on `application: didFinishLaunchingWithOptions:` in AppDelegate.
The request body structure is determined by `makeLocationDateDict` method.
*/
@objc class BackgroundLocationTracker: NSObject {
	
	//MARK:- Public members
	
	@objc static let shared = BackgroundLocationTracker()
	
	/**
	The minimum time interval (in seconds) before repeated location track (with further send to the backend).
	*/
	@objc var actionMinimumInterval: TimeInterval = 1 // 14 * 60
	
	/**
	A URL to send the update location request to.
	*/
	@objc var url: NSURL!
	
	/**
	A header to construct a location update request.
	*/
	@objc var httpHeaders: [String: String]!
	
	//MARK:- Private members
	
	/**
	The standard location manager.
	*/
	private let locationManager = CLLocationManager()
	
	/**
	Timestamp of the last location-date tracked.
	*/
	private var storedLastActionDate = StoredProperty<Date>(key: "LocationTracker.storedLastActionDate")
	
	/**
	An array with "location-date" dictionary records (see `makeTimeLocationDict` for the records structure), which hasn't been sent to the server for some reasons.
	*/
	private var storedUnsentLocations = StoredProperty<[[String: String]]>(key: "LocationTracker.storedUnsentLocations")
	
	/**
	Call the function on `application: didFinishLaunchingWithOptions:`.
	*/
	@objc func start(actionMinimumInterval: TimeInterval, url: NSURL, httpHeaders: [String: String]) {
		
		self.actionMinimumInterval = actionMinimumInterval
		self.url = url
		self.httpHeaders = httpHeaders
		
		setupLocationManager()
	}
		
}

//MARK:- Private
private extension BackgroundLocationTracker {

	func setupLocationManager() {
		locationManager.requestAlwaysAuthorization()
		locationManager.allowsBackgroundLocationUpdates = true

		locationManager.delegate = self
		locationManager.startMonitoringSignificantLocationChanges()
		
		locationManager.distanceFilter = 500;	// might be useless
	}
	
	/**
	The main function to trigger on location update
	*/
	func main(locations: [CLLocation]) {
		if let lastActionDate = storedLastActionDate.value,
			Date().timeIntervalSince(lastActionDate) < actionMinimumInterval {
			// The last action has been performed less than `actionMinInterval` seconds ago.
			return
		}
		// Record the new location
		if let lastLocation = locations.last {
			appendToSavedLocations(lastLocation)
			storedLastActionDate.value = Date()
		}
		
		sendSavedLocations()
	}
	
	/**
	Store the newly tracked location-date.
	*/
	func appendToSavedLocations(_ location: CLLocation) {
		var unsentLocations = storedUnsentLocations.value ?? [[String: String]]()
		unsentLocations.append(makeLocationDateDict(location: location))
		storedUnsentLocations.value = unsentLocations
	}
	
	/**
	Send all the saved locations to the specified `url` (see `makeTimeLocationDict` for the single "location" item structure).
	*/
	func sendSavedLocations() {
		guard let url = url else {
			// TODO: Report "no url" error
			return
		}
		
		guard let locations = storedUnsentLocations.value else { return }
		// Setup request
		var request = URLRequest(url: url as URL)
		request.httpMethod = "POST"
		// Headers
		var headersExtended = httpHeaders
		headersExtended?["Content-Type"] = "application/json"
		request.allHTTPHeaderFields = headersExtended
		// Body
		do {
			request.httpBody = try JSONSerialization.data(withJSONObject: locations, options: JSONSerialization.WritingOptions.prettyPrinted)
			if (request.httpBody?.count ?? 0) > 1_000_000_000 {
				// > ~1GB of unsent data - impossible in the case of normal flow
				emergencyUnsentLocationsCleanup()
				// TODO: report serialization error
			}
		} catch {
			emergencyUnsentLocationsCleanup()
			// TODO: report serialization error
		}
		// Send the request
		let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
			guard error == nil,
				let httpResponse = response as? HTTPURLResponse,
				200...299 ~= httpResponse.statusCode else {
				// do nothing - try again later
				return
			}
			// Delete locations which has been sent
			self.storedUnsentLocations.value = nil
		})
		task.resume()
	}
	
	/**
	Constrct a location-date dictionary to save -> send to the backend.
	*/
	func makeLocationDateDict(location: CLLocation) -> [String: String] {
		let result = [
			"lat": String(location.coordinate.latitude),
			"long": String(location.coordinate.longitude),
			"timestamp": Date().description
		]
		
		return result
	}
	
	/**
	Not supposed to be ever executed - just in case of unexpected cached data corruption or overflow.
	*/
	func emergencyUnsentLocationsCleanup() {
		self.storedUnsentLocations.value = nil
	}
}

//MARK:-
extension BackgroundLocationTracker: CLLocationManagerDelegate {
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		main(locations: locations)
	}
	
}
