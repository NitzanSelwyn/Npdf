import XCTest
@testable import NpdfKit
import PDFKit

final class CoordinateConverterTests: XCTestCase {
    // CoordinateConverter delegates to PDFView's convert methods,
    // so unit tests require a running PDFView — integration tests cover this.
    func testConverterInitializes() {
        let converter = CoordinateConverter()
        XCTAssertNotNil(converter)
    }
}

final class SignatureModelTests: XCTestCase {
    func testSignatureModelEncoding() throws {
        let model = SignatureModel(id: UUID(), name: "Test Sig", imagePath: "test.png")
        let data = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(SignatureModel.self, from: data)
        XCTAssertEqual(model.id, decoded.id)
        XCTAssertEqual(model.name, decoded.name)
        XCTAssertEqual(model.imagePath, decoded.imagePath)
        XCTAssertFalse(decoded.isDefault)
    }
}

final class StampAnnotationBuilderTests: XCTestCase {
    func testAllSymbolsCreateAnnotations() {
        let builder = StampAnnotationBuilder()
        // Create a dummy page using PDFDocument
        let doc = PDFDocument()
        let page = PDFPage()
        doc.insert(page, at: 0)

        for symbol in StampSymbol.allCases {
            let annotation = builder.makeAnnotation(
                symbol: symbol,
                at: CGPoint(x: 100, y: 100),
                size: 24,
                color: CGColor(red: 0, green: 0, blue: 1, alpha: 1),
                page: page
            )
            XCTAssertEqual(annotation.type, "Stamp", "Expected Stamp annotation for \(symbol)")
            XCTAssertEqual(annotation.toolTip, symbol.rawValue)
        }
    }
}

final class PDFLoaderTests: XCTestCase {
    func testLoadNonExistentFile() async {
        let loader = PDFLoader()
        let url = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).pdf")
        do {
            _ = try await loader.load(url: url)
            XCTFail("Expected error")
        } catch PDFLoaderError.corruptFile {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
