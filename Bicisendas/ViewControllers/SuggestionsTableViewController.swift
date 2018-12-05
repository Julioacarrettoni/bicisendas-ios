//
//  SuggestionsTableViewController.swift
//  Bicisendas
//
//  Created by Pablo Bendersky on 18/09/2018.
//  Copyright © 2018 Pablo Bendersky. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class SuggestionsTableViewController: UITableViewController {

    private let disposeBag = DisposeBag()

    var viewModel: RoutesViewModel! {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UINib(nibName: "SuggestionTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "SuggestionCell")
    }

    private func bindViewModel() {
        viewModel.newResults
            .subscribe(onNext: tableView.reloadData)
            .disposed(by: disposeBag)

        viewModel.currentRoute
            .filter { $0 != nil }
            .subscribe(onNext: unwindWithRoute(route:))
            .disposed(by: disposeBag)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.resultsCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath) as? SuggestionTableViewCell else {
            fatalError("Cell in \(#function) not of class SuggestionTableViewCell")
        }

        cell.updateWith(viewModel: viewModel.resultViewModel(atIndex: indexPath.row))

        cell.directionsAction
            .subscribe(onNext: directionsTapped(onCell:))
            .disposed(by: cell.cellDisposeBag)

        return cell
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {

        let cellViewModel = viewModel.resultViewModel(atIndex: indexPath.row)

        if cellViewModel.shouldHideDirections {
            viewModel.searchTerm.on(.next(cellViewModel.title))
        } else {
            searchDirections(forViewModel: cellViewModel)
        }

        return nil
    }

    private func directionsTapped(onCell cell: SuggestionTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }

        let cellViewModel = viewModel.resultViewModel(atIndex: indexPath.row)

        searchDirections(forViewModel: cellViewModel)
    }

    private func searchDirections(forViewModel cellViewModel: CompletionResultViewModel) {
        viewModel.toLocation.accept(.usigObject(container: cellViewModel.usigContainer))

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func unwindWithRoute(route: Route?) {
        performSegue(withIdentifier: "unwindToMapSegue", sender: route)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "unwindToMapSegue",
            let route = sender as? Route,
            let routeReciever = segue.destination as? RouteReceiver {

            routeReciever.setRoute(route)
        }
    }
}
