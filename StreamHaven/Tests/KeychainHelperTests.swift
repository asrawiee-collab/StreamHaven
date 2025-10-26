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
        let saved = KeychainHelper.savePassword(
            password: testPassword,
            for: testAccount,
            service: testService
        )
        XCTAssertTrue(saved, "Should save password successfully")
        
        let retrieved = KeychainHelper.getPassword(for: testAccount, service: testService)
        XCTAssertEqual(retrieved, testPassword, "Retrieved password should match saved password")
    }

    func testUpdateExistingPassword() {
        // Save initial password
        KeychainHelper.savePassword(
            password: testPassword,
            for: testAccount,
            service: testService
        )
        
        // Update with new password
        let newPassword = "NewPassword456"
        let updated = KeychainHelper.savePassword(
            password: newPassword,
            for: testAccount,
            service: testService
        )
        XCTAssertTrue(updated, "Should update password successfully")
        
        let retrieved = KeychainHelper.getPassword(for: testAccount, service: testService)
        XCTAssertEqual(retrieved, newPassword, "Should retrieve updated password")
    }

    func testDeletePassword() {
        // Save password
        KeychainHelper.savePassword(
            password: testPassword,
            for: testAccount,
            service: testService
        )
        
        // Delete it
        let deleted = KeychainHelper.deletePassword(for: testAccount, service: testService)
        XCTAssertTrue(deleted, "Should delete password successfully")
        
        // Verify it's gone
        let retrieved = KeychainHelper.getPassword(for: testAccount, service: testService)
        XCTAssertNil(retrieved, "Password should be nil after deletion")
    }

    func testRetrieveNonexistentPassword() {
        let retrieved = KeychainHelper.getPassword(
            for: "NonexistentAccount",
            service: testService
        )
        XCTAssertNil(retrieved, "Should return nil for nonexistent password")
    }

    func testDeleteNonexistentPassword() {
        let deleted = KeychainHelper.deletePassword(
            for: "NonexistentAccount",
            service: testService
        )
        // Deleting nonexistent item should return false or handle gracefully
        XCTAssertFalse(deleted, "Should return false when deleting nonexistent password")
    }

    func testSaveEmptyPassword() {
        let saved = KeychainHelper.savePassword(
            password: "",
            for: testAccount,
            service: testService
        )
        
        // Should handle empty password
        if saved {
            let retrieved = KeychainHelper.getPassword(for: testAccount, service: testService)
            XCTAssertEqual(retrieved, "", "Should retrieve empty password")
        }
    }

    func testSaveLongPassword() {
        let longPassword = String(repeating: "A", count: 1000)
        let saved = KeychainHelper.savePassword(
            password: longPassword,
            for: testAccount,
            service: testService
        )
        XCTAssertTrue(saved, "Should save long password")
        
        let retrieved = KeychainHelper.getPassword(for: testAccount, service: testService)
        XCTAssertEqual(retrieved, longPassword, "Should retrieve long password")
    }

    func testSavePasswordWithSpecialCharacters() {
        let specialPassword = "P@ssw0rd!#$%^&*()"
        let saved = KeychainHelper.savePassword(
            password: specialPassword,
            for: testAccount,
            service: testService
        )
        XCTAssertTrue(saved, "Should save password with special characters")
        
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
