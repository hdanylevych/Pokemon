//
//  NSManagedObject.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 26.10.2025.
//

extension NSManagedObject {
    class func get<T: NSManagedObject>(_ t: T.Type, by id: Int) -> T? {
        let context = PersistenceController.shared.container.viewContext
        
        do {
            let fetchRequest = T.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", NSNumber(value: id))
            let result = try context.fetch(fetchRequest)
            
            return result.first as? T
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    class func getAll<T: NSManagedObject>(_ t: T.Type) -> [T] {
        let request = T.fetchRequest()
        let context = PersistenceController.shared.container.viewContext
        
        do {
            guard let items = try context.fetch(request) as? [T] else { return [] }
            return items
        } catch {
            
        }
        
        return []
    }
    
    class func delete<T: NSManagedObject>(_ t: T.Type, id: Int) {
        guard let entity = T.get(T.self, by: id) else {
            return
        }
        
        PersistenceController.shared.container.viewContext.delete(entity)
        PersistenceController.shared.saveContext()
    }
}
