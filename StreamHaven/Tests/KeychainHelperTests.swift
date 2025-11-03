import XCTest
@testable import StreamHaven

final class KeychainHelperTests: XCTestCase {
    let testService = "com.test.StreamHaven"
    let testAccount = "TestAccount"
    let testPassword = "TestPassword123"

    override func tearDown() {
        // Clean up test data
        KeychainHelper.deletePassword(for: testAccount, service: testService)
    }

    func testSaveAndRetrievePassword() {
        KeychainHelper.savePassword(
            password: testPassword, for: testAccount, service: testService
        )
        
        let retrieved = KeychainHelper.getPassword(for: testAccount, service: testService)
        XCTAssertEqual(retrieved, testPassword, "Retrieved password should match saved password")
    }

    func testUpdateExistingPassword() {
        // Save initial password
        KeychainHelper.savePassword(
            password: testPassword, for: testAccount, service: testService
        )
        
        // Update with new password
        let newPassword = "NewPassword456"
        KeychainHelper.savePassword(
            password: newPassword, for: testAccount, service: testService
        )
        
        let retrieved = KeychainHelper.getPassword(for: testAccount, service: testService)
        XCTAssertEqual(retrieved, newPassword, "Should retrieve updated password")
    }

    func testDeletePassword() {
        // Save password
        KeychainHelper.savePassword(
            password: testPassword, for: testAccount, service: testService
        )
        
        // Delete it
        KeychainHelper.deletePassword(for: testAccount, service: testService)
        
        // Verify it's gone
        let retrieved = KeychainHelper.getPassword(for: testAccount, service: testService)
        XCTAssertNil(retrieved, "Password should be nil after deletion")
    }

    func testRetrieveNonexistentPassword() {
        let retrieved = KeychainHelper.getPassword(
            for: "NonexistentAccount", service: testService
        )
        XCTAssertNil(retrieved, "Should return nil for nonexistent password")
    }

    func testDeleteNonexistentPassword() {
        KeychainHelper.deletePassword(
            for: "NonexistentAccount", service: testService
        )
        // Deleting nonexistent item should not cause an error
    }

    func testSaveEmptyPassword() {
        KeychainHelper.savePassword(
            password: "", for: testAccount, service: testService
        )
        
        let retrieved = KeychainHelper.getPassword(for: testAccount, service: testService)
        XCTAssertEqual(retrieved, "", "Should retrieve empty password")
    }

    func testSaveLongPassword() {
        let longPassword = String(repeating: "A", count: 1000)
        KeychainHelper.savePassword(
            password: longPassword, for: testAccount, service: testService
        )
        
        let retrieved = KeychainHelper.getPassword(for: testAccount, service: testService)
        XCTAssertEqual(retrieved, longPassword, "Should retrieve long password")
    }

    func testSavePasswordWithSpecialCharacters() {
        let specialPassword = "P@ssw0rd!#$%^&*()"
        KeychainHelper.savePassword(
            password: specialPassword, for: testAccount, service: testService
        )
        
        let retrieved = KeychainHelper.getPassword(for: testAccount, service: testService)
        XCTAssertEqual(retrieved, specialPassword, "Should retrieve password with special characters")
    }

    func testMultipleAccountsSeparation() {
        let account1 = "Account1"
        let password1 = "Password1"
        let account2 = "Account2"
        let password2 = "Password2"
        
        KeychainHelper.savePassword(password: password1, for: account1, service: testService)
        KeychainHelper.savePassword(password: password2, for: account2, service: testService)
        
        let retrieved1 = KeychainHelper.getPassword(for: account1, service: testService)
        let retrieved2 = KeychainHelper.getPassword(for: account2, service: testService)
        
        XCTAssertEqual(retrieved1, password1)
        XCTAssertEqual(retrieved2, password2)
        
        // Cleanup
        KeychainHelper.deletePassword(for: account1, service: testService)
        KeychainHelper.deletePassword(for: account2, service: testService)
    }
}
