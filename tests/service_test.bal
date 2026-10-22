import ballerina/http;
import ballerina/test;
import reading_list_service.models;

// Stands in for bookstore-service on the port bookstoreServiceUrl's default already points at, so
// the service under test needs no configuration override to reach it.
listener http:Listener mockBookstore = new (9090);

isolated service /books on mockBookstore {
    isolated resource function get [int id]() returns models:Book|http:NotFound {
        if id == 1 {
            return {id: 1, title: "Dune", author: "Frank Herbert"};
        }
        return <http:NotFound>{body: {message: string `book ${id} not found`}};
    }
}

final http:Client readingListClient = check new ("http://localhost:9091/readinglist");

int duneEntryId = -1;

@test:Config {groups: ["service"]}
function testAddEntryForExistingBook() returns error? {
    http:Response response = check readingListClient->/.post({bookId: 1, reader: "Ada"});
    test:assertEquals(response.statusCode, http:STATUS_CREATED);

    models:EnrichedEntry created = check (check response.getJsonPayload()).cloneWithType();
    test:assertTrue(created.id > 0);
    test:assertEquals(created.status, "TO_READ");
    test:assertEquals(created.book, {id: 1, title: "Dune", author: "Frank Herbert"});
    test:assertEquals(check response.getHeader("Location"), string `/readinglist/${created.id}`);
    duneEntryId = created.id;
}

@test:Config {groups: ["service"]}
function testAddEntryForMissingBookReturnsBadRequest() returns error? {
    http:Response response = check readingListClient->/.post({bookId: 999, reader: "Ada"});
    test:assertEquals(response.statusCode, http:STATUS_BAD_REQUEST);
    test:assertEquals(check response.getJsonPayload(), {message: "book 999 not found in bookstore-service"});
}

@test:Config {groups: ["service"]}
function testAddEntryWithInvalidPayloadReturnsBadRequest() returns error? {
    http:Response response = check readingListClient->/.post({bookId: 0, reader: "Ada"});
    test:assertEquals(response.statusCode, http:STATUS_BAD_REQUEST);
    test:assertEquals(check response.getJsonPayload(), {message: "bookId must be a positive integer"});
}

@test:Config {groups: ["service"], dependsOn: [testAddEntryForExistingBook]}
function testGetEntryEnrichesWithCurrentBookDetails() returns error? {
    models:EnrichedEntry entry = check readingListClient->/[duneEntryId];
    test:assertEquals(entry.book, {id: 1, title: "Dune", author: "Frank Herbert"});
    test:assertEquals(entry.reader, "Ada");
}

@test:Config {groups: ["service"]}
function testGetMissingEntryReturnsNotFound() returns error? {
    http:Response response = check readingListClient->/[999999];
    test:assertEquals(response.statusCode, http:STATUS_NOT_FOUND);
    test:assertEquals(check response.getJsonPayload(), {message: "reading list entry 999999 not found"});
}

@test:Config {groups: ["service"], dependsOn: [testAddEntryForExistingBook]}
function testUpdateStatus() returns error? {
    models:ReadingListEntry updated = check readingListClient->/[duneEntryId]/status.put("READING");
    test:assertEquals(updated.status, "READING");
}

@test:Config {groups: ["service"], dependsOn: [testUpdateStatus, testGetEntryEnrichesWithCurrentBookDetails]}
function testListFiltersByReader() returns error? {
    models:ReadingListEntry[] mine = check readingListClient->/.get(reader = "Ada");
    test:assertTrue(mine.length() >= 1);
    models:ReadingListEntry[] nobody = check readingListClient->/.get(reader = "Nobody");
    test:assertEquals(nobody, []);
}

@test:Config {groups: ["service"], dependsOn: [testListFiltersByReader]}
function testDeleteEntry() returns error? {
    http:Response response = check readingListClient->/[duneEntryId].delete();
    test:assertEquals(response.statusCode, http:STATUS_NO_CONTENT);

    http:Response getResponse = check readingListClient->/[duneEntryId];
    test:assertEquals(getResponse.statusCode, http:STATUS_NOT_FOUND);
}
