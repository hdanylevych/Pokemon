//
//  CollectionView.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 26.10.2025.
//

extension UICollectionView {
    func registerCellWithotXib<T: UICollectionViewCell>(_ cls: T.Type) {
        let name = String(describing: cls.self)
        self.register(cls, forCellWithReuseIdentifier: name)
    }
    
    func dequeueCell<T>(cls: T.Type, indexPath path: IndexPath) -> T {
        let clsString = String(describing: T.self)
        guard let cell = self.dequeueReusableCell(withReuseIdentifier: clsString, for: path) as? T else {
            fatalError("Can not dequeue cell \(clsString)") }
        return cell
    }
}
