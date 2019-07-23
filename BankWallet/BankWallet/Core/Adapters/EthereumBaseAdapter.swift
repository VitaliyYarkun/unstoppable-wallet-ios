import EthereumKit
import RxSwift

class EthereumBaseAdapter {
    let ethereumKit: EthereumKit

    let wallet: Wallet
    let decimal: Int

    private let addressParser: IAddressParser
    let feeRateProvider: IFeeRateProvider

    init(wallet: Wallet, ethereumKit: EthereumKit, decimal: Int, addressParser: IAddressParser, feeRateProvider: IFeeRateProvider) {
        self.wallet = wallet
        self.ethereumKit = ethereumKit
        self.decimal = decimal
        self.addressParser = addressParser
        self.feeRateProvider = feeRateProvider
    }

    func balanceDecimal(balanceString: String?, decimal: Int) -> Decimal {
        if let balanceString = balanceString, let significand = Decimal(string: balanceString) {
            return Decimal(sign: .plus, exponent: -decimal, significand: significand)
        }
        return 0
    }

    func sendSingle(to address: String, value: String, gasPrice: Int) -> Single<Void> {
        fatalError("Method should be overridden in child class")
    }

    func createSendError(from error: Error) -> Error {
        if let error = error as? EthereumKit.NetworkError, case .noConnection = error {
            return SendTransactionError.connection
        } else {
            return SendTransactionError.unknown
        }
    }

}

extension EthereumBaseAdapter {

    var confirmationsThreshold: Int {
        return 12
    }

    func start() {
        // started via EthereumKitManager
    }

    func stop() {
        // stopped via EthereumKitManager
    }

    func refresh() {
        // refreshed via EthereumKitManager
    }

    var lastBlockHeight: Int? {
        return ethereumKit.lastBlockHeight
    }

    var lastBlockHeightUpdatedObservable: Observable<Void> {
        return ethereumKit.lastBlockHeightObservable.map { _ in () }
    }

    func sendSingle(params: [String: Any]) -> Single<Void> {
        guard let amount: Decimal = params[AdapterFields.amount.rawValue] as? Decimal, let address: String = params[AdapterFields.address.rawValue] as? String, let feeRatePriority: FeeRatePriority = params[AdapterFields.feeRateRriority.rawValue] as? FeeRatePriority else {
            return Single.error(AdapterError.wrongParameters)
        }

        let poweredDecimal = amount * pow(10, decimal)
        let handler = NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        let roundedDecimal = NSDecimalNumber(decimal: poweredDecimal).rounding(accordingToBehavior: handler).decimalValue

        let amountString = String(describing: roundedDecimal)

        return sendSingle(to: address, value: amountString, gasPrice: feeRateProvider.ethereumGasPrice(for: feeRatePriority))
    }

    func validate(address: String) throws {
        try ethereumKit.validate(address: address)
    }

    func parse(paymentAddress: String) -> PaymentRequestAddress {
        let paymentData = addressParser.parse(paymentAddress: paymentAddress)
        return PaymentRequestAddress(address: paymentData.address, amount: paymentData.amount.map { Decimal($0) })
    }

    var receiveAddress: String {
        return ethereumKit.receiveAddress
    }

    var debugInfo: String {
        return ethereumKit.debugInfo
    }

}
