import reading_list_service.catalog;
import reading_list_service.models;
import reading_list_service.store;

import ballerina/http;

# Port the reading-list service listens on.
configurable int port = 9091;

# Base URL of bookstore-service's /books API this service enriches entries from. Point this at
# bookstore-service's own endpoint URL for the target environment — its public URL if
# bookstore-service is public, or its organization-visibility URL if it's only reachable from
# inside the organization's dataplane.
configurable string bookstoreServiceUrl = "http://localhost:9090/books";

final store:ReadingList readingList = new;
final catalog:CatalogClient catalogClient = check new (bookstoreServiceUrl);

# REST API for a reader's reading list, backed by bookstore-service for book details.
isolated service http:InterceptableService /readinglist on new http:Listener(port) {

    public function createInterceptors() returns PayloadBindingErrorInterceptor {
        return new;
    }

    # Lists reading-list entries, optionally filtered by reader. Entries are not enriched with
    # book details here — fetching one book per entry from bookstore-service does not scale to a
    # list; fetch a single entry (which is enriched) when the book details are actually needed.
    #
    # + reader - reader to filter by
    # + return - the matching entries
    resource function get .(string? reader) returns models:ReadingListEntry[] {
        return readingList.list(reader);
    }

    # Fetches a single entry, enriched with its book's current details from bookstore-service.
    #
    # + id - the entry id
    # + return - the enriched entry, 404 if the entry does not exist or its book no longer does,
    #   or 502 if bookstore-service could not be reached
    resource function get [int id]() returns models:EnrichedEntry|http:NotFound|http:BadGateway {
        models:ReadingListEntry|store:NotFoundError entry = readingList.get(id);
        if entry is store:NotFoundError {
            return notFound(entry);
        }
        models:Book|catalog:BookNotFoundError|http:ClientError book = catalogClient->getBook(entry.bookId);
        if book is http:ClientError {
            return badGateway(book);
        }
        if book is catalog:BookNotFoundError {
            // The entry outlived the book: bookstore-service's data was reset, or the book was
            // deleted there after this entry was created.
            return notFound(book);
        }
        return {...entry, book};
    }

    # Adds a book to a reader's list. The book must exist in bookstore-service.
    #
    # + input - the entry details
    # + return - 201 with the created entry enriched with its book, 400 if the payload is invalid
    #   or the book does not exist, or 502 if bookstore-service could not be reached
    resource function post .(models:ReadingListEntryInput input) returns http:Created|http:BadRequest|http:BadGateway {
        models:ValidationError? invalid = models:validate(input);
        if invalid is models:ValidationError {
            return badRequest(invalid);
        }
        models:Book|catalog:BookNotFoundError|http:ClientError book = catalogClient->getBook(input.bookId);
        if book is http:ClientError {
            return badGateway(book);
        }
        if book is catalog:BookNotFoundError {
            return badRequest(book);
        }
        models:ReadingListEntry created = readingList.add(input);
        return <http:Created>{
            body: <models:EnrichedEntry>{...created, book},
            headers: {"Location": string `/readinglist/${created.id}`}
        };
    }

    # Updates a reader's progress on a book.
    #
    # + id - the entry id
    # + status - the new status
    # + return - the updated entry, or 404 if it does not exist
    resource function put [int id]/status(@http:Payload models:ReadingStatus status) returns models:ReadingListEntry|http:NotFound {
        models:ReadingListEntry|store:NotFoundError updated = readingList.updateStatus(id, status);
        if updated is store:NotFoundError {
            return notFound(updated);
        }
        return updated;
    }

    # Removes an entry.
    #
    # + id - the entry id
    # + return - 204 on success, or 404 if it does not exist
    resource function delete [int id]() returns http:NoContent|http:NotFound {
        store:NotFoundError? result = readingList.remove(id);
        if result is store:NotFoundError {
            return notFound(result);
        }
        return http:NO_CONTENT;
    }
}

# Turns request payloads that cannot be bound to the resource's expected type into a 400 with an
# `ErrorResponse` body.
isolated service class PayloadBindingErrorInterceptor {
    *http:ResponseErrorInterceptor;

    remote function interceptResponseError(error err) returns http:BadRequest|error {
        if err is http:PayloadBindingError {
            return badRequest(err);
        }
        // Anything else falls through to the listener's default error handling.
        return err;
    }
}

isolated function notFound(error err) returns http:NotFound => {body: <models:ErrorResponse>{message: err.message()}};

isolated function badRequest(error err) returns http:BadRequest => {body: <models:ErrorResponse>{message: err.message()}};

isolated function badGateway(error err) returns http:BadGateway =>
    {body: <models:ErrorResponse>{message: string `bookstore-service unavailable: ${err.message()}`}};
