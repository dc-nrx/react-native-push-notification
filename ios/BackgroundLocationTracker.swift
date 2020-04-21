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
	A URL to send the update location request to.
	*/
	var storedURLString = StoredProperty<String>(key: "BackgroundLocationTracker.storedURLString")
	
	/**
	A header to construct a location update request.
	*/
	var storedHTTPHeaders = StoredProperty<[String: String]>(key: "BackgroundLocationTracker.storedHTTPHeaders")
	
	//MARK:- Private members
	
	/**
	The standard location manager.
	*/
	private let locationManager = CLLocationManager()
	
	/**
	Timestamp of the last location-date tracked.
	*/
	private var storedLastActionDate = StoredProperty<Date>(key: "BackgroundLocationTracker.storedLastActionDate")
	
	/**
	An array with "location-date" dictionary records (see `makeTimeLocationDict` for the records structure), which hasn't been sent to the server for some reasons.
	*/
	private var storedUnsentLocations = StoredProperty<[[String: String]]>(key: "BackgroundLocationTracker.storedUnsentLocations")
	
	private var trackingEnabled = StoredProperty<Bool>(key: "BackgroundLocationTracker.trackingEnabled")
	
	/**
	Call the function whenever nesseccary; then to support background tracking you must call `continueIfAppropriate()` - see the doc.
	*/
	@objc func start(actionMinimumInterval: TimeInterval, url: NSURL, httpHeaders: [String: String]) {
		
		self.storedURLString.value = url.absoluteString
		self.storedHTTPHeaders.value = httpHeaders
		
		trackingEnabled.value = true
		setupLocationManager()
	}
	
	/**
	Call this method in `application: didFinishLaunchingWithOptions:` to enable background location updates
	If `start(...)` hasn't been called before, nothing will happen.
	*/
	@objc func continueIfAppropriate() {
		
//		Logger.log("continueIfAppropriate")
		if let isEnabled = trackingEnabled.value,
			isEnabled,
			self.storedURLString.value != nil,
			self.storedHTTPHeaders.value != nil {
			
			setupLocationManager()
		}
	}
	
	@objc func stop() {
		
//		Logger.log("stop")
		locationManager.stopMonitoringSignificantLocationChanges()
		locationManager.allowsBackgroundLocationUpdates = false
		
		storedURLString.value = nil
		storedHTTPHeaders.value = nil
		storedUnsentLocations.value = nil
		
		trackingEnabled.value = false
	}
}

//MARK:- Private
private extension BackgroundLocationTracker {

	func setupLocationManager() {
//		Logger.log("setup manager")
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
//		if let lastActionDate = storedLastActionDate.value,
//		Date().timeIntervalSince(lastActionDate) < storedActionMinimumInterval.value ?? 0 {
//			// The last action has been performed less than `actionMinInterval` seconds ago.
//			return
//		}
		// Record the new location
//		Logger.log("main")
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
//		Logger.log("send_1")
		guard let urlString = storedURLString.value,
			let url = URL(string: urlString),
			var httpHeaders = storedHTTPHeaders.value else {
			// TODO: Report "no url" error
			return
		}
		
		guard let locations = storedUnsentLocations.value else { return }
		// Setup request
		var request = URLRequest(url: url as URL)
		request.httpMethod = "POST"
		// Headers
		httpHeaders["Content-Type"] = "application/json"
		request.allHTTPHeaderFields = httpHeaders
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
//				Logger.log("send_error \(error) response: \(response)")
				return
			}
//			Logger.log("send_callback \(response)")
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
