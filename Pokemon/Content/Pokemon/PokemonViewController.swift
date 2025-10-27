//
//  PokemonViewController.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

final class PokemonViewController: UIViewController {
    private let scroll = UIScrollView()
    private let content = UIStackView()
    private let imageView = UIImageView()
    private let loader = UIActivityIndicatorView(style: .large)
    
    private let nameLabel = UILabel()
    private let idLabel = UILabel()
    private let heightLabel = UILabel()
    private let weightLabel = UILabel()
    
    private let favoriteButton = UIButton(type: .system)
    
    private let viewModel: PokemonViewModel
    private var bag = Set<AnyCancellable>()
    
    init(viewModel: PokemonViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.model.name.capitalized
        view.backgroundColor = .systemBackground
        configureViews()
        layoutViews()
        wireActions()
        bind()
        populateStaticInfo()
        viewModel.loadImageIfNeeded()
    }
    
    private func configureViews() {
        scroll.alwaysBounceVertical = true
        
        content.axis = .vertical
        content.spacing = 12
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = .init(top: 16, left: 16, bottom: 24, right: 16)
        
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemBackground
        imageView.layer.cornerRadius = 12
        
        loader.hidesWhenStopped = true
        
        nameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        nameLabel.textColor = .label
        
        idLabel.font = .systemFont(ofSize: 15, weight: .medium)
        idLabel.textColor = .secondaryLabel
        
        heightLabel.font = .systemFont(ofSize: 17, weight: .regular)
        heightLabel.textColor = .label
        
        weightLabel.font = .systemFont(ofSize: 17, weight: .regular)
        weightLabel.textColor = .label
        
        var fav = UIButton.Configuration.plain()
        fav.image = UIImage(systemName: "star")
        fav.preferredSymbolConfigurationForImage = .init(pointSize: 18, weight: .bold)
        fav.contentInsets = .init(top: 8, leading: 8, bottom: 8, trailing: 8)
        fav.background.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        fav.background.cornerRadius = 18
        fav.baseForegroundColor = .white
        favoriteButton.configuration = fav
        favoriteButton.layer.masksToBounds = true
        favoriteButton.accessibilityLabel = "Favorite"
    }
    
    private func layoutViews() {
        view.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        scroll.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        
        let imageContainer = UIView()
        imageContainer.addSubview(imageView)
        imageContainer.addSubview(loader)
        imageContainer.addSubview(favoriteButton)
        [imageView, loader, favoriteButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            
            loader.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            loader.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            
            favoriteButton.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 12),
            favoriteButton.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -12),
            favoriteButton.heightAnchor.constraint(equalToConstant: 36),
            favoriteButton.widthAnchor.constraint(equalToConstant: 36)
        ])
        
        let grid = UIStackView(arrangedSubviews: [idLabel, heightLabel, weightLabel])
        grid.axis = .vertical
        grid.spacing = 8
        
        content.addArrangedSubview(imageContainer)
        content.addArrangedSubview(nameLabel)
        content.addArrangedSubview(grid)
    }
    
    private func wireActions() {
        favoriteButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.viewModel.toggleFavorite()
        }, for: .touchUpInside)
    }
    
    private func bind() {
        viewModel.$isFavorite
            .receive(on: DispatchQueue.main)
            .sink { [weak self] on in
                guard let self else { return }
                self.setFavorite(on)
            }
            .store(in: &bag)
        
        viewModel.$image
            .receive(on: DispatchQueue.main)
            .sink { [weak self] img in
                guard let self else { return }
                self.imageView.image = img
            }
            .store(in: &bag)
        
        viewModel.$isImageLoading
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                loading ? self?.loader.startAnimating() : self?.loader.stopAnimating()
            }
            .store(in: &bag)
    }
    
    private func populateStaticInfo() {
        let m = viewModel.model
        nameLabel.text = m.name.capitalized
        idLabel.text = "#\(m.id)"
        
        let heightCm = m.height * 10
        let weightKg = Double(m.weight) / 10.0
        heightLabel.text = "Height: \(heightCm) cm"
        weightLabel.text = String(format: "Weight: %.1f kg", weightKg)
        
        setFavorite(viewModel.isFavorite)
    }
    
    private func setFavorite(_ on: Bool) {
        let imgName = on ? "star.fill" : "star"
        favoriteButton.configuration?.image = UIImage(systemName: imgName)
        favoriteButton.tintColor = on ? .systemYellow : .white
        favoriteButton.configuration?.baseForegroundColor = favoriteButton.tintColor
        favoriteButton.configuration?.background.backgroundColor = UIColor.black.withAlphaComponent(on ? 0.45 : 0.35)
    }
}
