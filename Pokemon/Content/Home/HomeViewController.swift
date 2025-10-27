//
//  HomeViewController.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

private enum Section: Int, Hashable { case main }

final class HomeViewController: UIViewController, UICollectionViewDelegate {
    private var collectionView: UICollectionView!
    private let viewModel: HomeViewModel
    private var bag = Set<AnyCancellable>()
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, Int>!
    private var indexByID: [Int: Int] = [:]
    
    private let activityIndicator: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    private let favoritesLabel: UILabel = {
        let favoritesLabel = UILabel()
        favoritesLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        favoritesLabel.textColor = .secondaryLabel
        favoritesLabel.text = "Favorites: 0"
        
        return favoritesLabel
    }()
    
    private let favoritesView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalCentering
        return stackView
    }()
    
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureDataSource()
        bind()
        viewModel.viewDidLoad()
    }
    
    private func configureView() {
        title = "Pokémon"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.registerCellWithotXib(HomeCell.self)
        
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor)
        ])
        
        favoritesView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            favoritesView.widthAnchor.constraint(equalToConstant: 100)
        ])
        
        favoritesView.addArrangedSubview(UIView())
        favoritesView.addArrangedSubview(favoritesLabel)
        favoritesView.addArrangedSubview(UIView())
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: favoritesView)
    }
    
    private func bind() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .idle:
                    break
                case .loading:
                    self?.activityIndicator.startAnimating()
                case .loaded:
                    self?.activityIndicator.stopAnimating()
                case .error(let desc):
                    self?.activityIndicator.stopAnimating()
                    self?.showRetryAlert(message: desc) {
                        self?.viewModel.retryTapped()
                    }
                }
            }
            .store(in: &bag)
        
        viewModel.$items
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newModels in
                self?.applySnapshot(items: newModels, animating: true)
            }
            .store(in: &bag)
        
        viewModel.$favoritesCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.favoritesLabel.text = "Favorites: \(count)"
            }
            .store(in: &bag)
        
        viewModel.cellUpdatesPublisher
            .collect(.byTime(DispatchQueue.main, .milliseconds(80)))
            .map { Array(Set($0)) }
            .filter { !$0.isEmpty }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ids in
                guard let self else { return }
                var snapshot = dataSource.snapshot()
                let snapshotIds = snapshot.itemIdentifiers(inSection: Section.main)
                let filteredIds = ids.filter { snapshotIds.contains($0) }
                
                snapshot.reconfigureItems(filteredIds)
                dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &bag)
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Int>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, id in
            guard let self else { return UICollectionViewCell() }
            
            let cell = collectionView.dequeueCell(cls: HomeCell.self, indexPath: indexPath)
            let items = self.viewModel.items
            if let modelIndex = self.indexByID[id] {
                let item = items[modelIndex]
                let image = item.imageURL.flatMap { self.viewModel.cachedImage(for: $0) }
                let isFavorite = self.viewModel.isFavorite(id: item.id)
                
                cell.configure(item: item, image: image, isFavorite: isFavorite)
                cell.onAction = { [weak self] action in self?.handle(action) }
                
                if image == nil {
                    self.viewModel.loadImageIfNeeded(forID: item.id)
                }
            }
            
            return cell
        }
    }
    
    private func applySnapshot(items: [PokemonModel], animating: Bool) {
        indexByID = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, Int>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items.map { $0.id }, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: animating)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        let items = viewModel.items
        guard !items.isEmpty else { return }
        let triggerIndex = max(0, items.count - 2)
        if indexPath.item >= triggerIndex {
            viewModel.didScrollToBottom()
        }
    }
    
    private func handle(_ action: HomeCell.Action) {
        switch action {
        case .tapCard(let id):
            viewModel.cardTapped(id: id)
        case .toggleFavorite(let id):
            viewModel.toggleFavorite(id: id)
        case .delete(let id):
            viewModel.delete(id: id)
        }
    }
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let spacing: CGFloat = 12
        let insets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                              heightDimension: .fractionalHeight(1.0))
        )
        
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                              heightDimension: .absolute(170)),
            subitem: item,
            count: 2
        )
        group.interItemSpacing = .fixed(spacing)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = insets
        section.interGroupSpacing = spacing
        return .init(section: section)
    }
    
    func showRetryAlert(message: String, retryHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "Error loading new items", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in retryHandler() })
        if !viewModel.items.isEmpty {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        }
        present(alert, animated: true)
    }
}
