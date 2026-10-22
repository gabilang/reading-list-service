import reading_list_service.models;

import ballerina/http;
import ballerina/test;

// Stands in for bookstore-service: /books/1 exists, everything else 404s, matching how a real
// http:Client call to a missing resource actually behaves.
listener http:Listener mockBookstore = new (9099);

isolated service /books on mockBookstore {
    isolated resource function get [int id]() returns models:Book|http:NotFound {
        if id == 1 {
            return {id: 1, title: "Dune", author: "Frank Herbert"};
        }
        return <http:NotFound>{body: {message: string `book ${id} not found`}};
    }
}

final CatalogClient catalogClient = check new ("http://localhost:9099/books");

@test:Config {groups: ["catalog"]}
function testGetBookReturnsBookDetails() returns error? {
    models:Book book = check catalogClient->getBook(1);
    test:assertEquals(book, {id: 1, title: "Dune", author: "Frank Herbert"});
}

@test:Config {groups: ["catalog"]}
function testGetBookMapsNotFoundToBookNotFoundError() {
    models:Book|BookNotFoundError|http:ClientError result = catalogClient->getBook(999);
    if result !is BookNotFoundError {
        test:assertFail("expected BookNotFoundError");
    }
    test:assertEquals(result.message(), "book 999 not found in bookstore-service");
}
