import UIKit
import SnapKit
import ThemeKit
import SectionsTableView
import HUD
import RxSwift
import ComponentKit

class FaqViewController: ThemeViewController {
    private let viewModel: FaqViewModel

    private let tableView = SectionsTableView(style: .plain)
    private let sectionFilterView = FilterHeaderView(buttonStyle: .tab)

    private let spinner = HUDActivityView.create(with: .large48)

    private let errorLabel = UILabel()

    private var currentSection = 0
    private var sectionItems = [FaqService.SectionItem]()

    private let disposeBag = DisposeBag()

    init(viewModel: FaqViewModel) {
        self.viewModel = viewModel

        super.init()

        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "faq.title".localized

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.sectionDataSource = self

        tableView.registerCell(forClass: FaqCell.self)
        tableView.registerCell(forClass: BCell.self)

        sectionFilterView.onSelect = { [weak self] index in
            self?.sectionFilterSelected(index: index)
        }

        view.addSubview(spinner)
        spinner.snp.makeConstraints { maker in
            maker.center.equalToSuperview()
        }

        view.addSubview(errorLabel)
        errorLabel.snp.makeConstraints { maker in
            maker.center.equalToSuperview()
        }

        errorLabel.font = .subhead2
        errorLabel.textColor = .themeGray

        viewModel.sectionItemsDriver
                .drive(onNext: { [weak self] in self?.sync(sectionItems: $0) })
                .disposed(by: disposeBag)

        viewModel.loadingDriver
                .drive(onNext: { [weak self] loading in
                    self?.setSpinner(visible: loading)
                })
                .disposed(by: disposeBag)

        viewModel.errorDriver
                .drive(onNext: { [weak self] error in
                    self?.errorLabel.text = error?.smartDescription
                })
                .disposed(by: disposeBag)

        tableView.buildSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        tableView.deselectCell(withCoordinator: transitionCoordinator, animated: animated)
    }

    private func setSpinner(visible: Bool) {
        if visible {
            spinner.isHidden = false
            spinner.startAnimating()
        } else {
            spinner.isHidden = true
            spinner.stopAnimating()
        }
    }

    private func sync(sectionItems: [FaqService.SectionItem]) {
        self.sectionItems = sectionItems

        sectionFilterView.reload(filters: sectionItems.map { FilterHeaderView.ViewItem.item(title: $0.title) })
        sectionFilterView.select(index: 0)
        currentSection = 0

        tableView.reload()
    }

    private func sectionFilterSelected(index: Int) {
        currentSection = index
        tableView.reload()
    }

}

extension FaqViewController: SectionsDataSource {

    private var transparentRow: RowProtocol {
        Row<UITableViewCell>(
                id: "transparent_row",
                height: 20,
                bind: { cell, _ in
                    cell.backgroundColor = .clear
                })
    }

    private func itemsSection(sectionIndex: Int, items: [FaqService.Item]) -> SectionProtocol {
        Section(
                id: "items-\(sectionIndex)",
                headerState: .static(view: sectionFilterView, height: .heightSingleLineCell),
                footerState: .marginColor(height: .margin32, color: .clear),
                rows: [transparentRow] + items.enumerated().map { index, item in
                    let isFirst = index == 0
                    let isLast = index == items.count - 1

                    return Row<FaqCell>(
                            id: "faq-\(sectionIndex)-\(index)",
                            dynamicHeight: { containerWidth in
                                FaqCell.height(containerWidth: containerWidth, text: item.text, backgroundStyle: .lawrence)
                            },
                            bind: { cell, _ in
                                cell.set(backgroundStyle: .lawrence, isFirst: isFirst, isLast: isLast)
                                cell.title = item.text
                            },
                            action: { [weak self] _ in
                                guard let url = item.url else {
                                    return
                                }

                                let module = MarkdownModule.viewController(url: url, handleRelativeUrl: false)
                                self?.navigationController?.pushViewController(module, animated: true)
                            }
                    )
                }
        )
    }

    func buildSections() -> [SectionProtocol] {
        var sections = [SectionProtocol]()

        guard currentSection < sectionItems.count else {
            return sections
        }

        sections.append(itemsSection(sectionIndex: currentSection, items: sectionItems[currentSection].items))

        return sections
    }

}
