import Foundation
import HandyOperators

protocol Keychain {
	func store(_ data: Data, forKey key: String) throws
	func loadData(forKey key: String) throws -> Data?
	func deleteEntry(forKey key: String) throws
}

extension Keychain {
	func loadString(forKey key: String) throws -> String? {
		try loadData(forKey: key).map {
			try String(bytes: $0, encoding: .utf8)
			??? KeychainDecodingError.invalidString
		}
	}
	
	func store(_ string: String, forKey key: String) throws {
		try store(Data(string.utf8), forKey: key)
	}
	
	func decode<T: Decodable>(_ type: T.Type = T.self, forKey key: String) throws -> T? {
		try loadData(forKey: key).map {
			try JSONDecoder().decode(T.self, from: $0)
		}
	}
	
	func encode(_ value: some Encodable, forKey key: String) throws {
		try store(JSONEncoder().encode(value), forKey: key)
	}
}

enum KeychainDecodingError: Error {
	case invalidString
}

extension Keychain where Self == OSKeychain {
	static var standard: Self { .instance }
}

final class OSKeychain: Keychain {
	static let instance = OSKeychain()
	
	private init() {}
	
	func store(_ data: Data, forKey key: String) throws {
		try Context(key: key).store(data)
	}
	
	func loadData(forKey key: String) throws -> Data? {
		try Context(key: key).loadData()
	}
	
	func deleteEntry(forKey key: String) throws {
		try Context(key: key).deleteEntry()
	}
	
	private struct Context {
		var key: String
		
		func makeQuery(setting attributes: [CFString: Any] = [:]) -> CFDictionary {
			attributes.merging([
				kSecClass: kSecClassGenericPassword,
				kSecAttrAccount: key,
			]) { (arg, def) in arg } as CFDictionary
		}
		
		func store(_ data: Data) throws {
			let attributes: [CFString: Any] = [
				kSecValueData: data,
				kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
			]
			if let _ = try? loadData() {
				try SecItemUpdate(makeQuery(), attributes as CFDictionary) <- checkStatus
			} else {
				let query = makeQuery(setting: attributes)
				try SecItemAdd(query, nil) <- checkStatus
			}
		}
		
		func loadData() throws -> Data? {
			let query = makeQuery(setting: [
				kSecReturnData: true,
			])
			
			var item: CFTypeRef?
			let status = SecItemCopyMatching(query, &item)
			guard status != errSecItemNotFound else { return nil }
			try checkStatus(status)
			return try item! as? Data ??? error(reason: .wrongType(type(of: item)))
		}
		
		func deleteEntry() throws {
			let query = makeQuery()
			try SecItemDelete(query) <- checkStatus
		}
		
		private func checkStatus(_ status: OSStatus) throws {
			guard status == noErr else {
				print(status)
				throw error(reason: .osError(status))
			}
		}
		
		func error(reason: KeychainError.Reason) -> KeychainError {
			.init(key: key, reason: reason)
		}
	}
	
	struct KeychainError: Error, LocalizedError {
		var key: String
		var reason: Reason
		
		var errorDescription: String? {
			String(localized: "Keychain error for key '\(key)': \(reason.description)", table: "Errors")
		}
		
		enum Reason: CustomStringConvertible {
			case osError(OSStatus)
			case wrongType(Any.Type)
			
			var description: String {
				switch self {
				case .osError(let status):
					return String(localized: "Unknown keychain error: \(status)", table: "Errors")
				case .wrongType(let type):
					return String(localized: "Unexpected type found: \("\(type)")", table: "Errors", comment: "Keychain error.")
				}
			}
		}
	}
}

final class MockKeychain: Keychain {
	var entries: [String: Data]
	
	init(entries: [String: Data] = [:]) {
		self.entries = entries
	}
	
	func store(_ data: Data, forKey key: String) throws {
		entries[key] = data
	}
	
	func loadData(forKey key: String) throws -> Data? {
		entries[key]
	}
	
	func deleteEntry(forKey key: String) throws {
		entries.removeValue(forKey: key)
	}
}

extension Keychain where Self == MockKeychain {
	static func mocked(entries: [String: Data] = [:]) -> Self {
		.init(entries: entries)
	}
}
