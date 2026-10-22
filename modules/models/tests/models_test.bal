import ballerina/test;

@test:Config {groups: ["models"]}
function testValidateAcceptsValidInput() {
    ValidationError? result = validate({bookId: 1, reader: "Ada"});
    test:assertTrue(result is ());
}

@test:Config {groups: ["models"]}
function testValidateRejectsNonPositiveBookId() {
    ValidationError? result = validate({bookId: 0, reader: "Ada"});
    if result !is ValidationError {
        test:assertFail("expected ValidationError");
    }
    test:assertEquals(result.message(), "bookId must be a positive integer");
}

@test:Config {groups: ["models"]}
function testValidateRejectsBlankReader() {
    ValidationError? result = validate({bookId: 1, reader: "   "});
    if result !is ValidationError {
        test:assertFail("expected ValidationError");
    }
    test:assertEquals(result.message(), "reader must not be empty");
}
