//
//  CDFavorites+CoreDataClass.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 25.10.2025.
//
//

@objc(CDFavorite)
public class CDFavorite: NSManagedObject {
    @discardableResult
    class func create(with id: Int) -> CDFavorite? {
        let entity = CDFavorite(context: PersistenceController.shared.container.viewContext)
        
        entity.id = Int32(id)
        
        PersistenceController.shared.saveContext()
        
        return entity
    }
}
