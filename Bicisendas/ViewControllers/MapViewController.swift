//
//  ViewController.swift
//  Bicisendas
//
//  Created by Pablo Bendersky on 10/08/2018.
//  Copyright © 2018 Pablo Bendersky. All rights reserved.
//

import UIKit

import MapKit

import RxSwift
import RxCocoa

class MapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var buttonContainerStackView: UIStackView!
    @IBOutlet weak var buttonContainerBackgroundView: UIVisualEffectView!
    @IBOutlet weak var warningButton: UIButton!
    @IBOutlet weak var bikeStationsButton: UIButton!
    @IBOutlet weak var routesButton: UIButton!
    @IBOutlet weak var currentRouteContainerView: UIView!
    @IBOutlet weak var currentRouteContainerBottomConstraint: NSLayoutConstraint!

    var userTrackingButton: MKUserTrackingButton!
    var compassButton: MKCompassButton!

    fileprivate var bikePathsRenderer: MKTileOverlayRenderer!

    private let locationManager = CLLocationManager()

    private let viewModel = MapViewModel()

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        registerMapViewAnnotations()

        bikeStationsButton.layer.cornerRadius = 5
        buttonContainerBackgroundView.layer.cornerRadius = 5

        locationManager.delegate = self

        requestLocationPermission()

        let cabaRegion = MKCoordinateRegion(center: CLLocationCoordinate2D.cabaCenter(),
                                            span: MKCoordinateSpan.cabaSpan())

        let region = mapView.regionThatFits(cabaRegion)
        mapView.setRegion(region, animated: true)
        mapView.showsCompass = false

        userTrackingButton = MKUserTrackingButton(mapView: mapView)
        userTrackingButton.translatesAutoresizingMaskIntoConstraints = false

        updateButtons(forLocationServicesEnabled: CLLocationManager.locationServicesEnabled())

        buttonContainerStackView.addArrangedSubview(userTrackingButton)

        compassButton = MKCompassButton(mapView: mapView)
        compassButton.compassVisibility = .adaptive

        view.addSubview(compassButton)

        compassButton.translatesAutoresizingMaskIntoConstraints = false
        compassButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20).isActive = true
        compassButton.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -20).isActive = true

        let overlay = BiciTileOverlay(urlTemplate: "https://tiles1.usig.buenosaires.gob.ar/mapcache/tms/1.0.0/ciclovias_caba_3857@GoogleMapsCompatible/{z}/{x}/{y}.png")

        overlay.minimumZ = 9
        overlay.maximumZ = 18

        bikePathsRenderer = MKTileOverlayRenderer(overlay: overlay)

        mapView.add(overlay, level: .aboveRoads)

        routesButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let strongSelf = self else { return }

                strongSelf.performSegue(withIdentifier: "routesSegue", sender: nil)
            })
            .disposed(by: disposeBag)

        bindUI()
    }

    private func registerMapViewAnnotations() {
        mapView.register(BikeStandMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(BikeStandMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
    }

    private func bindUI() {
        bikeStationsButton.rx.tap
            .bind(to: viewModel.showStationsAction)
            .disposed(by: disposeBag)

        viewModel.annotations
            .subscribe(onNext: { [weak self] (annotations) in

                guard let strongSelf = self else { return }

                strongSelf.mapView.removeAnnotations(strongSelf.mapView.annotations)
                strongSelf.mapView.addAnnotations(annotations)

            }, onError: { (error) in
                print(error)
            })
            .disposed(by: disposeBag)

        viewModel.showBikeStations
            .asObservable()
            .bind(to: bikeStationsButton.rx.isSelected)
            .disposed(by: disposeBag)

        viewModel.showBikeStations
            .asObservable()
            .filter { !$0 }
            .asDriver(onErrorJustReturn: false)
            .drive(onNext: { [weak self] _ in
                guard let strongSelf = self else { return }

                strongSelf.mapView.removeAnnotations(strongSelf.mapView.annotations)
            })
            .disposed(by: disposeBag)

        viewModel.activityIndicator
            .map { !$0 }
            .drive(bikeStationsButton.rx.isEnabled)
            .disposed(by: disposeBag)

        viewModel.currentRoute
            .asDriver(onErrorJustReturn: nil)
            .filter { $0 != nil }
            .drive(onNext: displayRoute(_:))
            .disposed(by: disposeBag)

        viewModel.currentRoute
            .skip(1)
            .asDriver(onErrorJustReturn: nil)
            .filter { $0 == nil }
            .drive(onNext: hideRoute(_:))
            .disposed(by: disposeBag)
    }

    private func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    fileprivate func updateButtons(forLocationServicesEnabled locationServicesEnabled: Bool) {
        userTrackingButton.isHidden = !locationServicesEnabled
        warningButton.isHidden = locationServicesEnabled
    }

    private func displayRoute(_ route: Route?) {
        guard let _ = route else { return }

        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.8,
                       options: .allowAnimatedContent,
                       animations: { [weak self] in

                        guard let strongSelf = self else { return }

                        strongSelf.currentRouteContainerBottomConstraint.constant = 0
                        strongSelf.view.layoutIfNeeded()

        }, completion: nil)
    }

    private func hideRoute(_ route: Route?) {
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.8,
                       options: .allowAnimatedContent,
                       animations: { [weak self] in

                        guard let strongSelf = self else { return }

                        strongSelf.currentRouteContainerBottomConstraint.constant = -strongSelf.currentRouteContainerView.frame.height
                        strongSelf.view.layoutIfNeeded()

            }, completion: nil)
    }

    @IBAction func warningButtonTapped(_ sender: Any) {
        let alertController = UIAlertController(title: NSLocalizedString("Location Disabled",
                                                                         comment: "Location Disabled Alert Title"),
                                                message: NSLocalizedString("Please enable access to your Location for this app to allow us to track you on the map.", comment: "Location Disabled Alert Text"),
                                                preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: NSLocalizedString("Later", comment: "Location Disabled Alert Cancel Action"),
                                         style: .cancel,
                                         handler: nil)
        alertController.addAction(cancelAction)

        let settingsAction = UIAlertAction(title: NSLocalizedString("Go to Settings", comment: "Location Disabled Alert Settings Action"),
                                           style: .default) { (_) in

            guard let settingsURL = URL(string: UIApplicationOpenSettingsURLString) else { return }

            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        }

        alertController.addAction(settingsAction)

        present(alertController, animated: true, completion: nil)
    }

    @IBAction func unwindToMapViewController(_ segue: UIStoryboardSegue) -> Void {
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "embedRouteSummarySegue",
            let destination = segue.destination as? RouteSummaryViewController {

            destination.viewModel = viewModel
        }
    }
}

class BiciTileOverlay: MKTileOverlay {

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let flippedY = (1 << path.z) - path.y - 1

        let tileUrl = "https://tiles1.usig.buenosaires.gob.ar/mapcache/tms/1.0.0/ciclovias_caba_3857@GoogleMapsCompatible/\(path.z)/\(path.x)/\(flippedY).png"

        return URL(string: tileUrl)!
    }

}

extension MapViewController: MKMapViewDelegate {

    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {

        return bikePathsRenderer
    }

}

extension MapViewController: CLLocationManagerDelegate {

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        let locationAvailable = (status == .authorizedAlways || status == .authorizedWhenInUse)

        updateButtons(forLocationServicesEnabled: locationAvailable)
    }
}

extension MapViewController: RouteReceiver {

    func setRoute(_ route: Route) {
        viewModel.currentRoute.onNext(route)
    }

}
