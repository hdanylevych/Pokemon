//
//  HomeCell.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

final class HomeCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let loader = UIActivityIndicatorView(style: .medium)
    private let infoBackground = UIView()
    private let nameLabel = UILabel()
    private let idLabel = UILabel()
    private let favoriteButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let tappableArea = UIControl()
    
    private var itemID: Int?
    private var isFavorite = false
    
    enum Action {
        case tapCard(id: Int)
        case toggleFavorite(id: Int)
        case delete(id: Int)
    }
    
    var onAction: ((Action) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
        layoutViews()
        wireActions()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        nameLabel.text = nil
        idLabel.text = nil
        itemID = nil
        isFavorite = false
        favoriteButton.isSelected = false
        favoriteButton.configuration?.image = UIImage(systemName: "star")
        favoriteButton.tintColor = .white
        favoriteButton.configuration?.baseForegroundColor = .white
        loader.stopAnimating()
        loader.isHidden = true
    }
    
    func configure(item: PokemonModel, image: UIImage?, isFavorite: Bool = false) {
        itemID = item.id
        nameLabel.text = item.name.capitalized
        idLabel.text = "#\(item.id)"
        setFavorite(isFavorite)
        
        if let image {
            imageView.image = image
            loader.stopAnimating()
            loader.isHidden = true
        } else {
            imageView.image = nil
            loader.isHidden = false
            loader.startAnimating()
        }
    }
    
    private func configureViews() {
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .secondarySystemBackground
        
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        loader.hidesWhenStopped = true
        loader.isHidden = true
        loader.color = .systemGray
        
        infoBackground.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        
        nameLabel.font = .boldSystemFont(ofSize: 16)
        nameLabel.textColor = .white
        
        idLabel.font = .systemFont(ofSize: 13, weight: .medium)
        idLabel.textColor = .white.withAlphaComponent(0.9)
        
        var favConfig = UIButton.Configuration.plain()
        favConfig.image = UIImage(systemName: "star")
        favConfig.preferredSymbolConfigurationForImage = .init(pointSize: 16, weight: .bold)
        favConfig.contentInsets = .init(top: 6, leading: 6, bottom: 6, trailing: 6)
        favConfig.background.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        favConfig.background.cornerRadius = 16
        favConfig.baseForegroundColor = .white
        favoriteButton.configuration = favConfig
        favoriteButton.layer.masksToBounds = true
        
        var delConfig = UIButton.Configuration.plain()
        delConfig.baseForegroundColor = .white
        delConfig.image = UIImage(systemName: "trash")
        deleteButton.configuration = delConfig
        
        tappableArea.backgroundColor = .clear
    }
    
    private func layoutViews() {
        contentView.addSubview(imageView)
        contentView.addSubview(loader)
        contentView.addSubview(infoBackground)
        contentView.addSubview(nameLabel)
        contentView.addSubview(idLabel)
        contentView.addSubview(favoriteButton)
        contentView.addSubview(deleteButton)
        contentView.addSubview(tappableArea)
        
        [imageView, loader, infoBackground, nameLabel, idLabel, favoriteButton, deleteButton, tappableArea]
            .forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            loader.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loader.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            infoBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            infoBackground.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            infoBackground.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            infoBackground.heightAnchor.constraint(equalToConstant: 48),
            
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            deleteButton.centerYAnchor.constraint(equalTo: infoBackground.centerYAnchor),
            
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: deleteButton.leadingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: infoBackground.topAnchor, constant: 6),
            
            idLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            idLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            idLabel.bottomAnchor.constraint(equalTo: infoBackground.bottomAnchor, constant: -6),
            
            tappableArea.topAnchor.constraint(equalTo: contentView.topAnchor),
            tappableArea.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tappableArea.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tappableArea.bottomAnchor.constraint(equalTo: infoBackground.topAnchor),
            
            favoriteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            favoriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            favoriteButton.heightAnchor.constraint(equalToConstant: 32),
            favoriteButton.widthAnchor.constraint(equalToConstant: 32),
        ])
        
        contentView.bringSubviewToFront(favoriteButton)
    }
    
    private func wireActions() {
        tappableArea.addTarget(self, action: #selector(handleTapCard), for: .touchUpInside)
        
        favoriteButton.addAction(UIAction { [weak self] _ in
            guard let self, let id = self.itemID else { return }
            self.isFavorite.toggle()
            self.setFavorite(self.isFavorite)
            self.onAction?(.toggleFavorite(id: id))
        }, for: .touchUpInside)
        
        deleteButton.addAction(UIAction { [weak self] _ in
            guard let self, let id = self.itemID else { return }
            self.onAction?(.delete(id: id))
        }, for: .touchUpInside)
    }
    
    @objc private func handleTapCard() {
        guard let id = itemID else { return }
        onAction?(.tapCard(id: id))
    }
    
    private func setFavorite(_ on: Bool) {
        isFavorite = on
        favoriteButton.isSelected = on
        let imgName = on ? "star.fill" : "star"
        favoriteButton.configuration?.image = UIImage(systemName: imgName)
        favoriteButton.tintColor = on ? .systemYellow : .white
        favoriteButton.configuration?.baseForegroundColor = favoriteButton.tintColor
    }
}
