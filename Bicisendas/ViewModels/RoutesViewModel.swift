//
//  RoutesViewModel.swift
//  Bicisendas
//
//  Created by Pablo Bendersky on 18/09/2018.
//  Copyright © 2018 Pablo Bendersky. All rights reserved.
//

import CoreLocation

import RxSwift
import RxCocoa

class RoutesViewModel {

    public var isReady = BehaviorRelay<Bool>(value: false)

    public var searchTerm = PublishSubject<String>()

    public var newResults = BehaviorRelay<Void>(value: Void())

    /// Emits a new value when there's an error in the USIG wrapper.
    public var error = BehaviorRelay<String?>(value: nil)

    public var fromLocation = BehaviorRelay<RouteLocationViewModel?>(value: .currentLocation)

    public var toLocation = BehaviorRelay<RouteLocationViewModel?>(value: nil)

    /// Emits a new value when we have found a pathway
    public var currentRoute = BehaviorRelay<Route?>(value: nil)

    public var resultsCount: Int {
        get {
            return completionResults.value.count
        }
    }

    private var completionResults = BehaviorRelay<[CompletionResultViewModel]>(value: [])

    private var usigWrapper = USIGWrapper()

    private let coordinateHelper = USIGCoordinateHelper()

    private let locationManager = CLLocationManager()

    private let disposeBag = DisposeBag()

    init() {
        usigWrapper.isReady
            .bind(to: isReady)
            .disposed(by: disposeBag)

        searchTerm
            .bind(to: usigWrapper.searchTerm)
            .disposed(by: disposeBag)

        usigWrapper.suggestions
            .map { (usigContainers) in
                usigContainers.map { CompletionResultViewModel(usigContainer: $0) }
            }
            .bind(to: completionResults)
            .disposed(by: disposeBag)

        usigWrapper.error
            .filter { $0 != nil }
            .bind(to: error)
            .disposed(by: disposeBag)

        completionResults
            .map { _ in
                return Void()
            }
            .bind(to: newResults)
            .disposed(by: disposeBag)

        bindSearch()
        bindResults()
    }

    private func bindSearch() {
        Observable.combineLatest(fromLocation, toLocation)
            .filter { $0.0 != nil && $0.1 != nil }
            .subscribe(onNext: { [weak self] in
                guard
                    let strongSelf = self,
                    let from = $0.0, let to = $0.1 else { return }

                do {

                    let fromUSIG = try strongSelf.toUSIGContainer(routeLocation: from)
                    let toUSIG = try strongSelf.toUSIGContainer(routeLocation: to)

                    strongSelf.usigWrapper.directions(from: fromUSIG, to: toUSIG)

                } catch {

                }
            })
            .disposed(by: disposeBag)
    }

    private func toUSIGContainer(routeLocation: RouteLocationViewModel) throws -> USIGContainer {
        switch routeLocation {
        case .currentLocation:
            guard let location = locationManager.location else { throw NSError() }

            let usigCoordinate = USIGCoordinateHelper.shared().convertToUSIG(coordinate: location.coordinate)

            let punto = PuntoDAO(coordX: usigCoordinate.x, coordY: usigCoordinate.y)

            let usigFrom = USIGContainer(usigType: .punto, usigObject: punto)

            return usigFrom
        case .usigObject(let container):
            return container
        }
    }

    private func bindResults() {
        let combinedFromTo = Observable.combineLatest(fromLocation, toLocation)

        usigWrapper.pathWay
            .filter { $0 != nil }
            .withLatestFrom(combinedFromTo, resultSelector: { (recorridoDAO, locations) -> Route in
                let (fromLocation, toLocation) = locations

                return Route(fromRecorrido: recorridoDAO!, fromLocation: fromLocation!, toLocation: toLocation!)
            })
            .bind(to: currentRoute)
            .disposed(by: disposeBag)
    }

    public func resultViewModel(atIndex index: Int) -> CompletionResultViewModel {
        return completionResults.value[index]
    }

}
