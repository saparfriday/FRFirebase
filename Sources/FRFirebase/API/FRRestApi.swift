//
//  File.swift
//  
//
//  Created by user on 02.11.2021.
//

import FirebaseFirestore
import FirebaseFirestoreSwift

enum FRRestApi {
    
    // MARK: - Create
    static func create<T: Codable>(model: T,
                                   ref: DocumentReference,
                                   completion: @escaping (Result<(T), Error>) -> Void) {
        do {
            try ref.setData(from: model)
            completion(.success(model))
        } catch let error {
            completion(.failure(error))
        }
    }
    
    // MARK: - Update
    static func update(data: [String: Any],
                       ref: DocumentReference,
                       completion: @escaping (Result<Bool, Error>) -> Void) {
        
        ref.updateData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(true))
            }
        }
    }
    
    // MARK: - Fetch ONE Document and return MODEL
    static func fetchModel<T: Codable>(model: T.Type,
                                       ref: DocumentReference,
                                       completion: @escaping (Result<T, Error>) -> Void) {
        
        ref.getDocument { (document, error) in
            if let document = document, document.exists {
                do {
                    let user = try document.data(as: model)
                    completion(.success(user!))
                } catch {
                    completion(.failure(error))
                }
            } else if let error = error {
                completion(.failure(error))
            } else {
                completion(.failure(NSError(domain: String.empty, code: 405, userInfo: [NSLocalizedDescriptionKey: "Document does not exist"])))
            }
        }
    }
    
    // MARK: - Fetch ONE Document and return VIEW MODEL
    static func fetchViewModel<T: Codable, M: DefaultConstructible>(model: T.Type,
                                                                    viewModel: M.Type,
                                                                    ref: DocumentReference,
                                                                    completion: @escaping (Result<M, Error>) -> Void) {
        
        fetchModel(model: model, ref: ref) { (result) in
            switch result {
            case .success(let model):
                let resultVM = viewModel.init(value: model)
                completion(.success(resultVM))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch MANY Documents and return MODELs
    static func fetchModels<T: Codable>(model: T.Type,
                                        query: Query,
                                        limit: Int? = nil,
                                        lastDocumentSnapshot: DocumentSnapshot? = nil,
                                        completion: @escaping (Result<([T], DocumentSnapshot, Bool), Error>) -> Void) {
        
        var editableQuery = query

        if let limit = limit {
            editableQuery = editableQuery.limit(to: limit)
        }
        
        if let lastDocumentSnapshot = lastDocumentSnapshot {
            editableQuery = editableQuery.start(afterDocument: lastDocumentSnapshot)
        }
        
        editableQuery.getDocuments { (querySnapshot, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.failure(error!))
                return
            }
            if documents.isEmpty {
                completion(.failure(NSError(domain: String.empty, code: 401, userInfo: [NSLocalizedDescriptionKey: "Documents not found"])))
                return
            }
            var models: [T] = []
            for document in documents {
                do {
                    let model = try document.data(as: model.self)
                    models.append(model!)
                } catch {
                    print("error with \(document.documentID) \(error)")
                    // completion(.failure(error)) : BUG
                }
            }
            completion(.success((models, documents.last!, limit == documents.count)))
            
        }
    }
    
    // MARK: - Fetch MANY Documents and return VIEW MODELs
    static func fetchViewModels<T: Codable, M: DefaultConstructible>(model: T.Type,
                                                                     viewModel: M.Type,
                                                                     query: Query,
                                                                     limit: Int? = nil,
                                                                     lastDocumentSnapshot: DocumentSnapshot? = nil,
                                                                     completion: @escaping (Result<([M], DocumentSnapshot, Bool), Error>) -> Void) {
        
        fetchModels(model: model, query: query, limit: limit, lastDocumentSnapshot: lastDocumentSnapshot) { (result) in
            switch result {
            case .success(let tupleResult):
                
                let (models, lastDocumentSnapshot, canLoadMore) = tupleResult
                var viewModels: [M] = []
                
                for model in models {
                    let resultVM = viewModel.init(value: model)
                    viewModels.append(resultVM)
                }
                completion(.success((viewModels, lastDocumentSnapshot, canLoadMore)))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Listen ONE Document and return MODEL
    static func listenModel<T: Codable>(model: T.Type,
                                        ref: DocumentReference,
                                        completion: @escaping (Result<T, Error>) -> Void,
                                        captureListener: @escaping (ListenerRegistration) -> Void) {
        
        let listenerRegistration = ref.addSnapshotListener { (document, error) in
            if let document = document, document.exists {
                do {
                    let model = try document.data(as: model)
                    completion(.success(model!))
                } catch {
                    completion(.failure(error))
                }
            } else if let error = error {
                completion(.failure(error))
            }
        }
        captureListener(listenerRegistration)
    }
    
    // MARK: - Listen ONE Document and return VIEW MODEL
    static func listenViewModel<T: Codable, M: DefaultConstructible>(model: T.Type,
                                                                     viewModel: M.Type,
                                                                     ref: DocumentReference,
                                                                     completion: @escaping (Result<M, Error>) -> Void,
                                                                     captureListener: @escaping (ListenerRegistration) -> Void) {
        
        let listenerRegistration = ref.addSnapshotListener { (document, error) in
            if let document = document, document.exists {
                do {
                    let model = try document.data(as: model)
                    let modelVM = viewModel.init(value: model)
                    completion(.success(modelVM))
                } catch {
                    completion(.failure(error))
                }
            } else if let error = error {
                completion(.failure(error))
            }
        }
        captureListener(listenerRegistration)
    }
    
    // MARK: - Listen MANY Documents and return MODELs
    static func listenModels<T: Codable>(model: T.Type,
                                         query: Query,
                                         limit: Int? = nil,
                                         completion: @escaping (Result<([T], DocumentSnapshot?, Bool), Error>) -> Void,
                                         captureListener: @escaping (ListenerRegistration) -> Void) {
        
        var editableQuery = query

        if let limit = limit {
            editableQuery = editableQuery.limit(to: limit)
        }
        
        let listenerRegistration = editableQuery.addSnapshotListener { (querySnapshot, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.failure(error!))
                return
            }
            if documents.isEmpty {
                completion(.success(([], nil, false)))
                // completion(.failure(NSError(domain: String.empty, code: 401, userInfo: [NSLocalizedDescriptionKey: "empty"])))
                return
            }
            var models: [T] = []
            for document in documents {
                do {
                    let model = try document.data(as: model.self)
                    models.append(model!)
                } catch {
                    // completion(.failure(error)) : BUG
                }
            }
            completion(.success((models, documents.last!, limit == documents.count)))
        }
        captureListener(listenerRegistration)
    }
    
    // MARK: - Listen MANY Documents and return VIEW MODELs
    static func listenViewModels<T: Codable, M: DefaultConstructible>(model: T.Type,
                                                                      viewModel: M.Type,
                                                                      query: Query,
                                                                      limit: Int? = nil,
                                                                      completion: @escaping (Result<([M], DocumentSnapshot?, Bool), Error>) -> Void,
                                                                      captureListener: @escaping (ListenerRegistration) -> Void) {
        
        listenModels(model: model, query: query, limit: limit) { result in
            switch result {
            case .success(let tupleResult):
                
                let (models, lastDocumentSnapshot, canLoadMore) = tupleResult
                var viewModels: [M] = []
                
                for model in models {
                    let resultVM = viewModel.init(value: model)
                    viewModels.append(resultVM)
                }
                completion(.success((viewModels, lastDocumentSnapshot, canLoadMore)))
                
            case .failure(let error):
                completion(.failure(error))
            }
        } captureListener: { listener in
            captureListener(listener)
        }
        
    }
    
}
