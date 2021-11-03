//
//  File.swift
//  
//
//  Created by user on 02.11.2021.
//

import Foundation
import FirebaseFirestore

public protocol FRViewModel {
    init(value: Codable)
}

final class FRFirestoreService<T: Codable, M: FRViewModel>: NSObject {
    
    // MARK: - Binding
    
    var isShowLoaderCell: ((_ status: Bool) -> Void)?
    var endRefreshing: (() -> Void)?
    var reloadWithData: (() -> Void)?
    
    // MARK: - Data
    
    private let isListen: Bool
    
    public var query: Query
    
    public var isInitialLoading: Bool = true
    
    private var limit: Int = 30
    
    private var increasingLimit: Int = 30
    
    public var lastDocumentSnapshot: DocumentSnapshot?
    
    private var currentListener: ListenerRegistration?
    
    public var canLoadMore = true
    
    private var isLoading = false
    
    public var models: [FRViewModel] = []
    
    public var hashableModels: [AnyHashable] {
        if let models = models as? [AnyHashable] {
            return models
        } else {
            return []
        }
    }
    
    // MARK: - Init
    
    init(isListen: Bool, query: Query, limit: Int = 30) {
        self.query = query
        self.isListen = isListen
        self.limit = limit
        self.increasingLimit = limit
    }
    
    deinit {
        currentListener?.remove()
    }
    
    required init?(coder: NSCoder) { nil }
    
    // MARK: - Handlers
    
    @objc
    public func reloadAndFetch() {
        if isListen {
            DispatchQueue.main.asyncAfter(deadline: (.now() + 0.5)) { [weak self] in
                self?.endRefreshing?()
            }
        } else {
            reloadAndSimpleFetch()
        }
    }
    
    // MARK: - Methods
    
    public func fetch() {
        if isListen {
            listenFetch()
        } else {
            simpleFetch()
        }
    }
    
    // MARK: - Helpers
    
    private func reloadAndSimpleFetch() {
        isLoading = false
        canLoadMore = true
        lastDocumentSnapshot = nil
        models = []
        simpleFetch()
    }
    
    private func listenFetch() {
        if !isLoading && canLoadMore {
            isLoading = true
            isShowLoaderCell?(true)
            models = []
            currentListener?.remove()
            
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                
                guard let strongSelf = self else { return }
                FRFirebase.Rest.listenViewModels(model: T.self, viewModel: M.self, query: strongSelf.query, limit: self?.limit) { result in
                    switch result {
                    case .success((let genericVMs, _, let canLoadMore)):
                        self?.canLoadMore = canLoadMore
                        if canLoadMore {
                            self?.limit += self?.increasingLimit ?? 30
                        }
                        self?.models = genericVMs
                    case .failure(let error):
                        debugPrint(error)
                        self?.canLoadMore = false
                    }
                    
                    self?.isInitialLoading = false
                    self?.reloadWithData?()
                    self?.isShowLoaderCell?(false)
                    
                    DispatchQueue.main.asyncAfter(deadline: (.now() + 0.5)) { [weak self] in
                        self?.isLoading = false
                        self?.endRefreshing?()
                    }
                    
                } captureListener: { [weak self] listener in
                    self?.currentListener = listener
                }
                
            }

        } else {
            DispatchQueue.main.asyncAfter(deadline: (.now() + 0.5)) { [weak self] in
                self?.endRefreshing?()
            }
        }
    }
    
    private func simpleFetch() {
        if !isLoading && canLoadMore {
            isLoading = true
            isShowLoaderCell?(true)
            
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                
                guard let strongSelf = self else { return }
                FRFirebase.Rest.fetchViewModels(
                    model: T.self,
                    viewModel: M.self,
                    query: strongSelf.query,
                    limit: strongSelf.limit,
                    lastDocumentSnapshot: strongSelf.lastDocumentSnapshot
                ) { result in
                    
                    switch result {
                    case .success((let genericVMs, let lastDocumentSnapshot, let canLoadMore)):
                        self?.models.append(contentsOf: genericVMs)
                        self?.lastDocumentSnapshot = lastDocumentSnapshot
                        self?.canLoadMore = canLoadMore
                    case .failure(_):
                        self?.canLoadMore = false
                    }
                    
                    self?.isInitialLoading = false
                    self?.reloadWithData?()
                    self?.isShowLoaderCell?(false)
                    
                    DispatchQueue.main.asyncAfter(deadline: (.now() + 0.5)) { [weak self] in
                        self?.isLoading = false
                        self?.endRefreshing?()
                    }
                }
                
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: (.now() + 0.5)) { [weak self] in
                self?.endRefreshing?()
            }
        }
    }
    
}
