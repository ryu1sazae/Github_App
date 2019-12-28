//
//  SearchUserViewModel.swift
//  Github_App
//
//  Created by 深見龍一 on 2019/12/28.
//  Copyright © 2019 深見龍一. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import Alamofire

protocol SearchUserViewModelInputs {
    var searchText: AnyObserver<String?>{ get }
    var itemSelected: AnyObserver<IndexPath>{ get }
}

protocol SearchUserViewModelOutputs {
    var searchResultText: Observable<String> { get }
    var users: Observable<[SearchUser.Item]> { get }
    var userName: Observable<String> { get }
}

protocol SearchUserViewModelType {
    var inputs: SearchUserViewModelInputs { get }
    var outputs: SearchUserViewModelOutputs { get }
}

final class SearchUserViewModel: SearchUserViewModelType, SearchUserViewModelInputs, SearchUserViewModelOutputs {
    

    // MARK: - Properties
    var inputs: SearchUserViewModelInputs { return self }
    var outputs: SearchUserViewModelOutputs { return self }

    let searchText: AnyObserver<String?>
    let itemSelected: AnyObserver<IndexPath>
    
    let searchResultText: Observable<String>
    let users: Observable<[SearchUser.Item]>
    let userName: Observable<String>
    
    private let disposeBag   = DisposeBag()
    
    // MARK: - Initializers
    init() {
        // Inputのpropertyの初期化
        let _searchText = BehaviorRelay<String>(value: "")
        self.searchText = AnyObserver<String?>() { event in
            guard let text = event.element else {
                return
            }
            _searchText.accept(text!)
            print(text!)
        }
        
        let _itemSelected = PublishRelay<IndexPath>()
        self.itemSelected = AnyObserver<IndexPath> { event in
            guard let indexPath = event.element else {
                return
            }
            _itemSelected.accept(indexPath)
        }
        
        // Ouputのpropertyの初期化
        let _searchResultText = BehaviorRelay<String>(value: "Github Search API")
        self.searchResultText = _searchResultText.asObservable().map{"User検索結果: " + $0 + "件"}
        
        let _users = BehaviorRelay<[SearchUser.Item]>(value: [])
        self.users = _users.asObservable()

        let _userName = PublishRelay<String>()
        self.userName = _userName.asObservable()

        // APIへのリクエスト
        _searchText
            .filter{ $0.count > 0 }
            .debounce(.milliseconds(500), scheduler: MainScheduler.instance) // 0.5s以上変更がなければ
            .subscribe({ value in
                self.api(users: _users, searchText: _searchText.value, searchResult: _searchResultText)
            })
            .disposed(by: self.disposeBag)
        
        // Itemが選択されたら、該当のindexのPageのURLを取り出す
        _itemSelected
            .withLatestFrom(_users) { ($0.row, $1) }
            .flatMap { index, users -> Observable<String> in
                guard index < users.count else {
                    return .empty()
                }
                return .just(users[index].login)
            }
            .bind(to: _userName)
            .disposed(by: disposeBag)
    }

    
    // MARK: - Functions
    func api(users: BehaviorRelay<[SearchUser.Item]>, searchText: String, searchResult: BehaviorRelay<String>)
    {
        let url = "https://api.github.com/search/users?q=" + searchText
        var usersItem: [SearchUser.Item] = []
        Alamofire.request(url, method: .get, parameters: nil)
        .validate(statusCode: 200..<300)
        .validate(contentType: ["application/json"])
        .responseJSON { response in
            switch response.result {
                case .success:
                    print("success!")
                    guard let data = response.data else {
                        return
                    }
                    let decoder = JSONDecoder()
                    do {
                        let items: SearchUser = try decoder.decode(SearchUser.self, from: data)
                        searchResult.accept(String(items.total_count))
                        for item in items.items
                        {
                            usersItem.append(item)
                        }
                        users.accept(usersItem)
                    } catch {
                        print("error:")
                        print(error)
                    }
                case .failure:
                    print("Failure!")
                    searchResult.accept(String(0))
            }
        }
    }
}
