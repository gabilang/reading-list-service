import reading_list_service.models;

import ballerina/http;

# Returned when bookstore-service has no book for the given id.
public type BookNotFoundError distinct error;

# Thin client over bookstore-service's catalog. Isolates the base URL and the
# 404-vs-everything-else distinction from callers that just want a book by id.
public isolated client class CatalogClient {
    private final http:Client bookstore;

    public isolated function init(string baseUrl) returns error? {
        self.bookstore = check new (baseUrl);
    }

    # Fetches a book from bookstore-service.
    #
    # + id - the book id
    # + return - the book, a `BookNotFoundError` if bookstore-service has none, or the underlying
    #   `http:ClientError` for anything else — bookstore-service unreachable, wrong response shape
    isolated remote function getBook(int id) returns models:Book|BookNotFoundError|http:ClientError {
        models:Book|http:ClientError result = self.bookstore->/[id];
        if result is http:ClientRequestError && result.detail().statusCode == http:STATUS_NOT_FOUND {
            return error BookNotFoundError(string `book ${id} not found in bookstore-service`);
        }
        return result;
    }
}
