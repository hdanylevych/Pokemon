//
//  CDFavorites+CoreDataProperties.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 25.10.2025.
//
//

extension CDFavorite {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDFavorite> {
        return NSFetchRequest<CDFavorite>(entityName: "CDFavorite")
    }

    @NSManaged public var id: Int32

}

extension CDFavorite : Identifiable {

}
