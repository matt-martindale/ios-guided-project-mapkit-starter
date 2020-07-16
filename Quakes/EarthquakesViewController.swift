//
//  EarthquakesViewController.swift
//  Quakes
//
//  Created by Paul Solt on 10/3/19.
//  Copyright © 2019 Lambda, Inc. All rights reserved.
//

import UIKit
import MapKit

extension String {
    static let annotationReuseIdentifier = "QuakeAnnotationView"
}

class EarthquakesViewController: UIViewController {
    
    private let quakeFetcher = QuakeFetcher()
    
    @IBOutlet var mapView: MKMapView!
    private var userTrackingButton: MKUserTrackingButton!
    
    private let locationManager = CLLocationManager()
    
    private var isCurrentlyFetchingQuakes = false
    private var shouldRequestQuakesAgain = false
    
    var quakes: [Quake] = [] {
        didSet {
            let oldQuakes = Set(oldValue)
            let newQuakes = Set(quakes)
            
            let addedQuakes = Array(newQuakes.subtracting(oldQuakes))
            let removedQuakes = Array(oldQuakes.subtracting(newQuakes))
            
            mapView.removeAnnotations(removedQuakes)
            mapView.addAnnotations(addedQuakes)
        }
    }
	
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.requestWhenInUseAuthorization()
        
        userTrackingButton = MKUserTrackingButton(mapView: mapView)
        userTrackingButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(userTrackingButton)
        
        NSLayoutConstraint.activate([
            userTrackingButton.leadingAnchor.constraint(equalTo: mapView.leadingAnchor, constant: 20),
            mapView.bottomAnchor.constraint(equalTo: userTrackingButton.bottomAnchor, constant: 20)
        ])
        
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: .annotationReuseIdentifier)
        
        fetchQuakes()
    }
    
    func fetchQuakes() {
        // If we were already requesting quakes...
        guard !isCurrentlyFetchingQuakes else {
            // ... then we want to remember to refresh once the busy request comes back
            shouldRequestQuakesAgain = true
            return
        }
        
        isCurrentlyFetchingQuakes = true
        
        let visibleRegion = mapView.visibleMapRect
        quakeFetcher.fetchQuakes(in: visibleRegion) { (quakes, error) in
            self.isCurrentlyFetchingQuakes = false
            
            defer {
                if self.shouldRequestQuakesAgain {
                    self.shouldRequestQuakesAgain = false
                    self.fetchQuakes()
                }
            }
            
            if let error = error {
                NSLog("%@", "Error fetching quakes: \(error)")
            }
            
            guard let quakes = quakes else {
                self.quakes = []
                return
            }
            
            let sortedQuakes = quakes.sorted { (a, b) -> Bool in
                a.magnitude > b.magnitude
            }
            
            self.quakes = Array(sortedQuakes.prefix(100))
        }
    }
    
}

extension EarthquakesViewController: MKMapViewDelegate {
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        fetchQuakes()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let quake = annotation as? Quake else { return nil }
        
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: .annotationReuseIdentifier, for: quake) as? MKMarkerAnnotationView else {
            preconditionFailure("Missing the registered map annotation view")
        }
        
        annotationView.glyphImage = #imageLiteral(resourceName: "QuakeIcon")
        
        switch quake.magnitude {
        case -10..<3: annotationView.markerTintColor = .systemYellow
        case 3..<5: annotationView.markerTintColor = .systemOrange
        case 5..<7: annotationView.markerTintColor = .systemRed
        default: annotationView.markerTintColor = .systemPurple
        }
        
        annotationView.canShowCallout = true
        let detailView = QuakeDetailView()
        detailView.quake = quake
        annotationView.detailCalloutAccessoryView = detailView
        
        return annotationView
    }
}
